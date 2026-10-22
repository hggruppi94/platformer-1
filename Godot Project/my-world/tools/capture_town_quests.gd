extends SceneTree

# Screenshots of Pip's lamps and Bramble's window flowers: a glow shell by the lake at night, the boardwalk before
# and after Pip's moon-lamps, window boxes before and after Bramble's flowers. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_town_quests.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://town_quest_shots"
var clock: Node
var dialogue: Node
var quests: Node
var player: Node3D
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	create_timer(200.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	clock = root.get_node("Clock")
	dialogue = root.get_node("Dialogue")
	quests = root.get_node("Quests")
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	game._resume = {}
	game.pending_message = ""
	dialogue.reset()
	quests.load_data({"rex_campaign": {"step": 6, "since_day": 1, "done": true}, "pip_lamps": {"step": 0, "since_day": 1}})
	change_scene_to_file(TOWN)
	for i in 6:
		await process_frame
	player = current_scene.find_child("Player", true, false)
	player.get_node("HUD").visible = false
	player.global_position = Vector3(-140, 2, 100)
	cam = Camera3D.new()
	cam.fov = 60
	current_scene.add_child(cam)
	cam.make_current()

	clock.set_time(1, 22 * 60.0, true)
	await create_timer(2.5).timeout
	var shell := current_scene.find_child("Glow Shell 2", true, false) as Node3D
	await _view("01_glow_shell_by_the_lake_at_night", shell.global_position + Vector3(2.4, 1.4, 2.6), shell.global_position + Vector3(0, 0.3, 0))
	var bw := Vector3(-7, 0.3, 4)
	await _view("02_boardwalk_before_pip", bw + Vector3(7, 5, 16), bw + Vector3(0, 1, -4))
	quests.load_data({"rex_campaign": {"step": 6, "since_day": 1, "done": true}, "pip_lamps": {"step": 2, "since_day": 1, "done": true}})
	quests.changed.emit("pip_lamps")
	await create_timer(0.5).timeout
	await _view("03_boardwalk_with_pips_moon_lamps", bw + Vector3(7, 5, 16), bw + Vector3(0, 1, -4))
	await _view("04_moon_lamps_close_up", bw + Vector3(4, 2.2, 8), bw + Vector3(-1, 1.8, 0))

	clock.set_time(2, 11 * 60.0, true)
	await create_timer(2.5).timeout
	var hall := current_scene.find_child("Town Hall", false, false) as Node3D
	var a := -0.42
	var front := Vector3(sin(a), 0, cos(a))
	await _view("05_window_box_empty", hall.global_position + front * 13.0 + Vector3(0, 3.5, 0), hall.global_position + front * 7.0 + Vector3(0, 1.8, 0))
	quests.load_data({"rex_campaign": {"step": 6, "since_day": 1, "done": true}, "bramble_flowers": {"step": 1, "since_day": 2}})
	for f in ["flowers_town_hall", "flowers_ninas_house", "flowers_potion_shop", "flowers_book_store", "flowers_dashs_house"]:
		dialogue.set_flag(f)
	await create_timer(0.5).timeout
	await _view("06_window_box_blooming", hall.global_position + front * 13.0 + Vector3(0, 3.5, 0), hall.global_position + front * 7.0 + Vector3(0, 1.8, 0))
	var home := current_scene.find_child("Nina's House", false, false) as Node3D
	var ha := home.rotation.y + 0.84
	var hf := Vector3(sin(ha), 0, cos(ha))
	await _view("07_ninas_house_window_box", home.global_position + hf * 10.0 + Vector3(0, 3.0, 0), home.global_position + hf * 4.5 + Vector3(0, 1.0, 0))
	quests.load_data({"rex_campaign": {"step": 6, "since_day": 1, "done": true}, "bramble_flowers": {"step": 2, "since_day": 2, "done": true}})
	quests.changed.emit("bramble_flowers")
	await create_timer(0.5).timeout
	var m := Vector3(-72, 0, 42)
	await _view("08_market_shops_all_blooming", m + Vector3(14, 9, 18), m + Vector3(-4, 1, -4))
	_finish()


func _view(file: String, from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()

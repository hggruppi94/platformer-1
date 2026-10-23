extends SceneTree

# Screenshots of the castle school (tools/build_school.gd): the Entrance Garden with its greenhouse and vegetable
# beds, inside the greenhouse, and the view of the mountains from the 3rd floor's window wall by day and by night.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_school_garden.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const SCHOOL := "res://scenes/school/school.tscn"
const BS := preload("res://tools/build_school.gd")

var out_dir := "user://school_garden_shots"
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	create_timer(120.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	var clock := root.get_node("Clock")
	game._resume = {}
	game.pending_message = ""
	clock.set_time(1, 13 * 60.0, true)                   # early afternoon
	game.next_spawn = "FromTown"
	change_scene_to_file(SCHOOL)
	for i in 8:
		await process_frame
	await create_timer(1.0).timeout
	var player := current_scene.find_child("Player", true, false) as Node3D
	player.get_node("HUD").visible = false
	cam = Camera3D.new()
	cam.fov = 65
	current_scene.add_child(cam)
	cam.make_current()
	var zs := BS.Z_S
	await _view("01_garden_from_the_gate", Vector3(6, 5.5, zs + 19), Vector3(-2, 0.5, zs + 6))
	await _view("02_greenhouse_and_path", Vector3(2.5, 2.2, zs + 14), Vector3(-12, 1.2, zs + 8))
	await _view("03_inside_the_greenhouse", Vector3(-7.2, 1.7, zs + 11.5), Vector3(-16, 0.9, zs + 5))
	await _view("04_vegetable_beds", Vector3(5, 2.4, zs + 15), Vector3(13, 0.4, zs + 5))
	player.global_position = Vector3(0, 2 * BS.FLOOR_H + 1.0, BS.Z_N + 4)
	await _view("05_third_floor_window_wall", Vector3(-20, 2 * BS.FLOOR_H + 1.8, BS.Z_N + 5), Vector3(4, 2 * BS.FLOOR_H + 3.0, BS.Z_N - 6))
	await _view("06_mountains_from_the_window", Vector3(0, 2 * BS.FLOOR_H + 1.7, BS.Z_N + 3), Vector3(0, 2 * BS.FLOOR_H + 6.5, BS.Z_N - 60))
	clock.set_time(1, 21 * 60.0 + 30.0, true)             # a clear night
	await create_timer(0.3).timeout
	await _view("07_window_at_night", Vector3(0, 2 * BS.FLOOR_H + 1.7, BS.Z_N + 3), Vector3(0, 2 * BS.FLOOR_H + 6.5, BS.Z_N - 60))
	_finish()


func _view(file: String, at: Vector3, look: Vector3) -> void:
	cam.global_position = at
	cam.look_at(look)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()

extends SceneTree

# Screenshots of the Crocodillo (scenes/enemies/crocodillo.tscn) by the castle's pond at midday: standing, from the
# side, curled up into its armoured ball, and dizzy after a roll. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_crocodillo.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://crocodillo_shots"
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(120.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	game._resume = {}
	game.pending_message = ""
	change_scene_to_file(TOWN)
	for i in 6:
		await process_frame
	root.get_node("Clock").set_time(1, 12 * 60.0, true)
	var town := current_scene as Node3D
	var player := town.find_child("Player", true, false) as Node3D
	player.global_position = Vector3(-140, 2, 100)
	player.get_node("HUD").visible = false
	var croc := town.find_child("Crocodillo 0", true, false) as Node3D
	croc.set_physics_process(false)                   # hold it still for the pictures
	var visual := croc.get_node("Visual") as Node3D
	visual.rotation.y = 0.0
	cam = Camera3D.new()
	cam.fov = 45
	town.add_child(cam)
	cam.make_current()
	var c := croc.global_position
	await _view("01_crocodillo", c + Vector3(1.2, 1.6, 4.2), c + Vector3(0, 1.1, 0))
	await _view("02_side", c + Vector3(4.2, 1.5, 0.6), c + Vector3(0, 1.0, 0))
	croc.get_node("Visual/Body").visible = false
	croc.get_node("Visual/Ball").visible = true
	await _view("03_curled_up", c + Vector3(1.5, 1.4, 3.2), c + Vector3(0, 0.7, 0))
	croc.get_node("Visual/Body").visible = true
	croc.get_node("Visual/Ball").visible = false
	croc.get_node("Visual/Stars").visible = true
	await _view("04_dizzy", c + Vector3(-1.5, 2.0, 3.8), c + Vector3(0, 1.4, 0))
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
		DirAccess.rename_absolute(BACKUP, SAVE)
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()

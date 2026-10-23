extends SceneTree

# Screenshots of the barn dance studio in the Earth town (tools/build_earth.gd): from the corner of the green, its
# front yard, inside (the mirror wall and the disco ball), and Madame Celeste. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_dance_studio.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const EARTH := "res://scenes/earth/earth.tscn"
const BE := preload("res://tools/build_earth.gd")

var out_dir := "user://dance_studio_shots"
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
	clock.set_time(1, 12.0, true)                         # the Shift, when the portal to Earth is open
	clock.earth_minutes = 16 * 60.0 + 20.0                # a golden autumn afternoon there
	game.next_spawn = "Entrance"
	change_scene_to_file(EARTH)
	for i in 8:
		await process_frame
	await create_timer(1.0).timeout
	var player := current_scene.find_child("Player", true, false) as Node3D
	player.get_node("HUD").visible = false
	player.global_position = Vector3(-30, 1, -30)
	cam = Camera3D.new()
	cam.fov = 60
	current_scene.add_child(cam)
	cam.make_current()
	var s := BE.STUDIO_AT
	var toward := Vector3(-s.x, 0, -s.z).normalized()
	var side := Vector3(toward.z, 0, -toward.x)
	var front := s + toward * (BE.STUDIO_SIZE.z / 2.0)
	await _view("01_from_the_corner_of_the_green", front + toward * 16.0 + side * 5.0 + Vector3(0, 4.0, 0), s + Vector3(0, 4, 0))
	await _view("02_the_front_yard", front + toward * 7.0 - side * 3.0 + Vector3(0, 1.7, 0), front + Vector3(0, 3.0, 0))
	await _view("03_inside_the_studio", front - toward * 1.0 + side * 2.5 + Vector3(0, 2.2, 0), s - toward * 6.0 + Vector3(0, 2.0, 0))
	await _view("04_madame_celeste", s + toward * 4.6 + side * 1.2 + Vector3(0, 1.7, 0), s + toward * 2.0 + Vector3(0, 1.4, 0))
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

extends SceneTree

# Screenshots of the Astronaut by the Mothership Pad: walking up to them from the player's own camera (with the talk
# prompt), a wide view with the pad and the Observatory hill, a close-up, and the same spot at night.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_astronaut.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://astronaut_shots"
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
	var clock := root.get_node("Clock")
	clock.set_time(1, 12 * 60.0, true)
	var town := current_scene as Node3D
	var p := town.find_child("Player", true, false) as CharacterBody3D
	var arm := p.get_node("SpringArm3D") as SpringArm3D
	var astro := town.find_child("Astronaut", true, false) as Node3D
	var at := astro.global_position
	var facing := Vector3(sin(astro.rotation.y), 0, cos(astro.rotation.y))   # the way they look (models face +Z)
	cam = Camera3D.new()
	cam.fov = 45
	town.add_child(cam)

	# 1. Walking up to them, from the player's own camera, close enough for the talk prompt
	var from := Vector3(0.8, 0, 0.6)                          # coming from the south-east, where it's open
	p.global_position = at + from * 2.2 + Vector3(0, 0.9, 0)
	var yaw := atan2(-from.x, -from.z)
	(p.get_node("Visual") as Node3D).rotation.y = yaw
	arm.rotation = Vector3(-0.2, yaw + PI, 0)
	await _game_view("01_walking_up", 20)

	# 2. Wide: the astronaut by the pad, with the Observatory hill behind
	p.global_position = at + Vector3(-30, 5, 30)               # out of the way
	cam.make_current()
	await _view("02_by_the_mothership_pad", at + Vector3(7, 2.5, 8), at + Vector3(0.5, 3.0, -4))

	# 3. Close-up, front on
	await _view("03_close_up", at + facing * 3.2 + Vector3(0, 1.4, 0), at + Vector3(0, 1.1, 0))

	# 4. Night: the stars are out
	clock.set_time(1, 22 * 60.0, true)
	await _view("04_at_night", at + facing * 5.0 + Vector3(-1.5, 1.8, 0), at + Vector3(0, 1.6, 0))
	_finish()


func _game_view(file: String, frames: int) -> void:
	# What the player sees: their own camera
	(cam.get_parent().find_child("Player", true, false).get_node("SpringArm3D/Camera3D") as Camera3D).make_current()
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _view(file: String, at: Vector3, look: Vector3) -> void:
	cam.global_position = at
	cam.look_at(look)
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()

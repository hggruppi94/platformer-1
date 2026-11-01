extends SceneTree

# Screenshots of the Boulderdillo in Boulder Hollow (scripts/crocodillo_boss.gd, placed by scripts/bosses.gd): the
# hollow from above, the boss up close next to an ordinary Crocodillo, curled up into its boulder ball, slamming a ring
# out, and a Pebbledillo. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_boss_versions.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.boss_versions_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://boss_version_shots"
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(300.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	game._resume = {}
	game.pending_message = ""
	root.get_node("Settings").tips = false
	change_scene_to_file(TOWN)
	for i in 8:
		await process_frame
	root.get_node("Clock").set_time(1, 12 * 60.0, true)
	var town := current_scene as Node3D
	var player := town.find_child("Player", true, false) as Node3D
	player.get_node("HUD").visible = false
	var hollow := town.get_node("Boulder Hollow") as Node3D
	var boss := town.find_child("The Boulderdillo", true, false) as Node3D
	cam = Camera3D.new()
	cam.fov = 50
	town.add_child(cam)
	cam.make_current()
	var h := hollow.global_position
	player.global_position = h + Vector3(4, 1.5, 22)
	for i in 40:
		await physics_frame
	for e in town.find_child("Enemies", true, false).get_children():
		e.set_physics_process(false)
	var b := boss.global_position
	(boss.get_node("Visual") as Node3D).rotation.y = 0.0
	await _view("01_boulder_hollow", h + Vector3(10, 16, 30), h)
	# An ordinary Crocodillo beside it, for size
	var croc := (load("res://scenes/enemies/crocodillo.tscn") as PackedScene).instantiate() as Node3D
	croc.name = "Size Check"
	town.add_child(croc)
	croc.set_physics_process(false)
	croc.global_position = b + Vector3(3.5, 0, 2.5)
	await _view("02_boulderdillo_and_a_crocodillo", b + Vector3(3.0, 4.0, 13.0), b + Vector3(1.0, 2.5, 0))
	croc.queue_free()
	await _view("03_boulderdillo_close_up", b + Vector3(-3.5, 5.0, 8.0), b + Vector3(0, 3.6, 0.5))
	# Curled up into its boulder ball, slamming a ring out
	boss.get_node("Visual/Body").visible = false
	boss.get_node("Visual/Ball").visible = true
	await _view("04_curled_up_boulder_ball", b + Vector3(5.0, 4.0, 9.0), b + Vector3(0, 1.8, 0))
	cam.global_position = b + Vector3(10.0, 10.0, 16.0)
	cam.look_at(b + Vector3(0, 0.5, 0))
	Engine.time_scale = 0.2
	boss.call("_slam", 7.0)
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("05_slam_ring.png"))
	Engine.time_scale = 1.0
	print("SHOT 05_slam_ring")
	boss.get_node("Visual/Body").visible = true
	boss.get_node("Visual/Ball").visible = false
	boss.call("_call_pebbles", 2)
	for i in 4:
		await process_frame
	for c in town.find_children("Pebbledillo *", "", true, false):
		c.set_physics_process(false)
	await _view("06_boulderdillo_and_pebbledillos", b + Vector3(-6.0, 5.0, 11.0), b + Vector3(0, 1.5, 0))


func _view(file: String, at: Vector3, look: Vector3) -> void:
	cam.global_position = at
	cam.look_at(look)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	Engine.time_scale = 1.0
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()

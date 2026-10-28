extends SceneTree

# Screenshots of Mr. Palmer's Galaxity form (scripts/palmer_trunk.gd): at his spot by the Town Hall window with his tea
# table, a close-up, mid-sip with the teacup up on his trunk, his evening stroll round the market, and the Town Hall at
# night with him gone in to bed.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_palmer.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const FAR_AWAY := Vector3(-140, 2, 100)

var out_dir := "user://palmer_shots"
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(180.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	game.riding = false
	game._resume = {}
	game.pending_message = ""
	change_scene_to_file(TOWN)
	for i in 6:
		await process_frame
	var clock := root.get_node("Clock")
	var town := current_scene as Node3D
	var p := town.find_child("Player", true, false) as Node3D
	p.global_position = FAR_AWAY
	clock.set_time(1, 10 * 60.0, true)
	for i in 8:
		await physics_frame
	var palmer := town.find_child("MrPalmer", true, false) as Node3D
	var trunk := palmer.get_node("Trunk")
	var anim := palmer.find_child("AnimationPlayer", true, false) as AnimationPlayer
	cam = Camera3D.new()
	cam.fov = 45
	town.add_child(cam)
	var at := palmer.global_position
	var front := palmer.global_transform.basis.z
	var side := front.cross(Vector3.UP)

	# 1. At his spot by the Town Hall window, tea table in front of him
	await _view("01_office_hours", at + front * 4.2 + side * 2.2 + Vector3(0, 1.6, 0), at + Vector3(0, 1.0, 0))
	# 2. Close-up
	await _view("02_close_up", at + front * 1.9 + side * 0.7 + Vector3(0, 1.45, 0), at + Vector3(0, 1.25, 0))
	# 3. Mid-sip: the teacup up on the end of his trunk
	trunk.call("sip")
	while anim.current_animation == "grab" and anim.current_animation_position < 1.3:
		await process_frame
	anim.speed_scale = 0.0                       # hold the pose (still "playing", so he keeps hold of the cup)
	await _view("03_sip", at + front * 2.0 - side * 1.6 + Vector3(0, 1.4, 0), at + front * 0.4 + Vector3(0, 1.25, 0))
	anim.speed_scale = 1.0
	for i in 60:
		await physics_frame

	# 4. His evening stroll round the market
	clock.set_time(1, 18 * 60.0 + 30.0, true)
	for i in 8:
		await physics_frame
	var stroll := palmer.global_position
	var f2 := palmer.global_transform.basis.z
	await _view("04_evening_stroll", stroll + f2 * 4.0 + f2.cross(Vector3.UP) * 1.5 + Vector3(0, 1.7, 0), stroll + Vector3(0, 1.0, 0))

	# 5. Night: he's gone in; the table waits by the window
	clock.set_time(1, 22 * 60.0, true)
	for i in 8:
		await physics_frame
	await _view("05_night_gone_in", at + front * 7.0 + side * 3.0 + Vector3(0, 2.4, 0), at + Vector3(0, 1.5, 0))
	_finish()


func _view(file: String, at: Vector3, look: Vector3) -> void:
	cam.make_current()
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

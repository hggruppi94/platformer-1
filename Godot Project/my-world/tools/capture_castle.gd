extends SceneTree

# Screenshots of the castle school (Bojnice Castle, built by tools/build_town.gd) at midday: from the lake, at the
# gate, from the air and from the side, then the mothership in the green sky. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_castle.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const BT := preload("res://tools/build_town.gd")

var out_dir := "user://castle_shots"
var town: Node3D
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
	# Put your save aside. If a backup is already there, an earlier run stopped before putting it back: that backup
	# is your real save, so keep it rather than copying this run's test save over it.
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	game._resume = {}
	game.pending_message = ""
	change_scene_to_file(TOWN)
	for i in 6:
		await process_frame
	root.get_node("Clock").set_time(1, 12 * 60.0, true)
	town = current_scene as Node3D
	var player := town.find_child("Player", true, false) as Node3D
	player.global_position = Vector3(-140, 2, 100)
	player.get_node("HUD").visible = false
	cam = Camera3D.new()
	cam.fov = 60
	cam.far = 1200
	town.add_child(cam)
	cam.make_current()
	var hill := Vector3(BT.CASTLE_HILL.x, BT.CASTLE_HILL.z, BT.CASTLE_HILL.y)
	var gate := (town.get_node("Castle School/SchoolEntrance") as Node3D).global_position
	await _view("01_from_the_lake", Vector3(4, 8, -20), hill + Vector3(0, 22, 0))
	await _view("02_at_the_gate", gate + Vector3(6, 6, 34), gate + Vector3(0, 10, 0))
	await _view("03_from_the_air", hill + Vector3(-110, 85, 95), hill + Vector3(0, 5, 0))
	await _view("04_from_the_east", hill + Vector3(120, 30, -10), hill + Vector3(0, 20, 0))
	var ship := town.get_node_or_null("Mothership") as Node3D
	if ship:
		ship.set_process(false)                       # hold it still for the picture
		await _view("05_mothership_in_the_green_sky", ship.global_position + Vector3(-60, -55, 70), ship.global_position)
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

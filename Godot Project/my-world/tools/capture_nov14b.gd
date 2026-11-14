extends SceneTree

# Screenshots for Hayden's 14 Nov 2026 afternoon playtest fixes (thread "Fix bugs from the 14 Nov afternoon
# playtest"): the Island Park (the town square between the lakes), the cloud with the Toy Store and the water slide's
# start, the school's north-east break corner by Behind the Walls, and Otto in his bubble. Opens a window:
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_nov14b.gd -- <output folder>
#
# Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.nov14b_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.nov14b_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const SCHOOL := "res://scenes/school/school.tscn"

var out_dir := "user://nov14b_shots"
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(600.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var game := root.get_node("Game")
	var clock := root.get_node("Clock")
	game._resume = {}
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Settings").tips = false
	clock.pulls_home = false
	clock.on_earth = false
	clock.set_time(3, 11 * 60.0, true)
	game.give_item("cloud_slide")
	var only := OS.get_cmdline_user_args().slice(1)
	change_scene_to_file(TOWN)
	await _frames(14)
	var p := current_scene.find_child("Player", true, false) as CharacterBody3D
	(p.get_node("HUD") as CanvasLayer).visible = false
	_new_cam()
	var sq := (current_scene.get_node("TownSquare") as Node3D).global_position
	p.global_position = sq + Vector3(30, 2, 30)
	await _view("01_island_park", sq + Vector3(13, 6, 13), sq, 12)
	await _view("02_island_park_low", sq + Vector3(8, 1.6, -6), sq, 4)
	await _view("03_island_park_top", sq + Vector3(0, 25, 1), sq, 4)
	var mk := (current_scene.get_node("Market Square") as Node3D).global_position
	await _view("04_market_square", mk + Vector3(20, 9, 20), mk, 8)
	var bench := mk + Vector3(cos(deg_to_rad(45.0)), 0, sin(deg_to_rad(45.0))) * 6.0
	await _view("04b_market_bench", bench + Vector3(3.5, 1.4, 2.5), bench, 4)
	await _view("04c_market_fountain", mk + Vector3(5, 1.5, 4), mk + Vector3(0, 0.6, 0), 4)
	var cloud := Vector3(-28, 20, 6)
	await _view("05_cloud_toy_store", cloud + Vector3(14, 6, 14), cloud + Vector3(-2.5, 1, -2), 12)
	await _view("06_cloud_slide_start", cloud + Vector3(4, 4, -16), cloud + Vector3(0, 0, -8), 4)
	await _view("07_cloud_from_below", cloud + Vector3(18, -8, 18), cloud, 4)
	var otto: Node3D = load("res://scripts/tide_reef.gd").otto_model()
	current_scene.add_child(otto)
	otto.global_position = sq + Vector3(0, 30, 0)
	await _view("08_otto", otto.global_position + Vector3(0, 1.4, 3.6), otto.global_position + Vector3(0, 1.0, 0), 8)
	otto.queue_free()
	change_scene_to_file(SCHOOL)
	await _frames(14)
	p = current_scene.find_child("Player", true, false) as CharacterBody3D
	if p:
		(p.get_node("HUD") as CanvasLayer).visible = false
	_new_cam()
	var bc := Vector3(23.3, 0.0, -17.3)
	for n in current_scene.find_children("Break Corner*", "Node3D", true, false):
		var g: Vector3 = (n as Node3D).global_position
		if Vector2(g.x, g.z).distance_to(Vector2(23.3, -17.3)) < 1.0:
			bc = g
	# From just under the ceiling, looking down on the rug and beanbags with both walls in view.
	await _view("09_school_break_corner", bc + Vector3(-0.6, 5.5, 0.6), bc + Vector3(0.8, 0, -0.8), 10)
	# From inside the passage behind the wall, looking along it past the corner: nothing should poke through.
	await _view("10_behind_the_walls", Vector3(14, bc.y + 1.5, -22.5), Vector3(26, bc.y + 0.6, -22.5), 4)
	_finish()


func _new_cam() -> void:
	cam = Camera3D.new()
	cam.fov = 60
	current_scene.add_child(cam)
	cam.make_current()


func _view(file: String, at: Vector3, look: Vector3, settle := 8) -> void:
	cam.make_current()
	cam.global_position = at
	cam.look_at(look)
	await _shot(file, settle)


func _shot(file: String, settle := 4) -> void:
	for i in settle:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	else:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	quit()

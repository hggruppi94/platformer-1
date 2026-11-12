extends SceneTree

# Screenshots of the Seer at home in the Observatory (scenes/interiors/observatory.tscn, scripts/seer.gd) and the
# Wizard Lizard in his principal's office at the castle school (scripts/council.gd). Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_council.gd -- <output folder>
#
# Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.council_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.council_capture_backup.cfg"
const OBSERVATORY := "res://scenes/interiors/observatory.tscn"
const SCHOOL := "res://scenes/school/school.tscn"

var out_dir := "user://council_shots"
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
	clock.set_time(3, 22 * 60.0, true)

	# The Observatory: the room, the Council's table, the Seer by her telescope, her corner
	change_scene_to_file(OBSERVATORY)
	await _frames(20)
	_hide_hud()
	var p := current_scene.find_child("Player", true, false) as Node3D
	p.global_position = Vector3(0, 1, 9)
	_new_cam()
	var seer := current_scene.get_node("The Seer") as Node3D
	var s := seer.global_position
	await _view("01_the_observatory", Vector3(0, 3.2, 9.6), Vector3(0, 2.2, -3))
	await _view("02_the_seer_at_home", s + Vector3(-1.4, 1.5, 3.0), s + Vector3(0, 1.0, 0))
	await _view("03_the_council_table", Vector3(-1.2, 3.2, 4.5), Vector3(-5, 0.9, 0))
	await _view("04_her_corner", Vector3(2.5, 2.4, 5.5), Vector3(7, 0.7, 0))
	await _view("05_the_seer_close", s + Vector3(-0.4, 1.45, 1.5), s + Vector3(0, 1.3, 0))

	# The castle school: the foyer sign, then the principal's office
	change_scene_to_file(SCHOOL)
	await _frames(20)
	_hide_hud()
	p = current_scene.find_child("Player", true, false) as Node3D
	p.global_position = Vector3(-12, 13, -14)
	_new_cam()
	await _view("06_school_foyer_sign", Vector3(0, 2.4, 21), Vector3(0, 2.0, 15))
	var council := root.get_node("Watches/Council")
	var liz: Node3D = council.principal()
	var l := liz.global_position if liz else Vector3(0.3, 12, 4.5)
	await _view("07_principals_door", Vector3(-12.5, 14.6, 4.5), Vector3(-7, 14.6, 4.5))
	await _view("08_principals_office", Vector3(-6.2, 14.4, 1.0), l + Vector3(0, 0.8, 0))
	await _view("09_the_wizard_lizard", l + Vector3(-2.2, 1.5, 0.8), l + Vector3(0, 1.0, 0))
	_finish()


func _hide_hud() -> void:
	var p := current_scene.find_child("Player", true, false)
	if p and p.get_node_or_null("HUD"):
		(p.get_node("HUD") as CanvasLayer).visible = false


func _new_cam() -> void:
	cam = Camera3D.new()
	cam.fov = 55
	current_scene.add_child(cam)
	cam.make_current()


func _view(file: String, at: Vector3, look: Vector3, settle := 10) -> void:
	cam.make_current()
	cam.global_position = at
	cam.look_at(look)
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

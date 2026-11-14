extends SceneTree

# Screenshots of the Gloop Gate from outside, the way you walk up to it from the town (scripts/bosses.gd and the
# kingdom round it, scripts/gloop_gate_view.gd), and the first look up the Bog Road inside (scripts/gloop_kingdom.gd).
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_gloop_gate.gd -- <output folder>
#
# Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.gate_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.gate_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://gate_shots"
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(900.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var game := root.get_node("Game")
	var clock := root.get_node("Clock")
	var bosses := root.get_node("Bosses")
	game._resume = {}
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Settings").tips = false
	clock.pulls_home = false
	clock.on_earth = false
	clock.set_time(3, 11 * 60.0, true)

	# The gate, out in the west fields, seen the way you walk up to it from the town
	change_scene_to_file(TOWN)
	await _frames(12)
	var gate := current_scene.get_node("Gloop Gate") as Node3D
	var p := current_scene.find_child("Player", true, false) as CharacterBody3D
	(p.get_node("HUD") as CanvasLayer).visible = false
	p.global_position = gate.global_position + Vector3(9, 1, 3)
	_new_cam()
	var g := gate.global_position
	# (each camera stands just above the ground where it is, so none ends up inside a hill)
	await _view("01_from_the_west_fields", _eye(bosses, 60, -14, 2.5), g + Vector3(-30, 10.0, 0), 12)
	await _view("02_walking_up", _eye(bosses, 32, 6, 1.8), g + Vector3(-15, 7.0, 0))
	await _view("03_at_the_gate", _eye(bosses, 13, 3, 1.8), g + Vector3(0, 4.0, 0))
	await _view("04_from_above", g + Vector3(45, 34, 45), g + Vector3(-35, 0, 0))
	await _view("05_from_the_market", _eye(bosses, 100, 4, 9.0), g + Vector3(-30, 12.0, 0), 12)

	# In: the first look up the Bog Road
	bosses.enter_kingdom()
	await _frames(14)
	var kd := current_scene as Node3D
	p = kd.find_child("Player", true, false) as CharacterBody3D
	(p.get_node("HUD") as CanvasLayer).visible = false
	_new_cam()
	await _view("06_first_look_inside", Vector3(0, 2.6, 0.5), Vector3(0, 4.0, 40), 12)
	_finish()


func _eye(bosses: Node, dx: float, dz: float, up: float) -> Vector3:
	# A spot dx, dz from the gate, "up" metres over the ground there
	return bosses.ground(current_scene, bosses.GATE.x + dx, bosses.GATE.y + dz) + Vector3(0, up, 0)


func _new_cam() -> void:
	cam = Camera3D.new()
	cam.fov = 55
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


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


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

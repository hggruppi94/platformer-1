extends SceneTree

# Screenshots of the Gloop Kingdom (scripts/gloop_kingdom.gd): the Gloop Gate in the west fields, the Bog Road, the
# moat and its pads, the Palace Gate, the Royal Court from above, the King on his throne, the fight, and the Royal
# Treasure open afterwards. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_gloop_kingdom.gd -- <output folder>
#
# Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.kingdom_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.kingdom_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://kingdom_shots"
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

	# The gate, out in the west fields
	change_scene_to_file(TOWN)
	await _frames(12)
	var gate := current_scene.get_node("Gloop Gate") as Node3D
	var p := current_scene.find_child("Player", true, false) as CharacterBody3D
	(p.get_node("HUD") as CanvasLayer).visible = false
	p.global_position = gate.global_position + Vector3(9, 1, 3)
	_new_cam()
	await _view("01_the_gloop_gate", gate.global_position + Vector3(16, 4.5, 9), gate.global_position + Vector3(0, 2.5, 0))
	await _view("02_the_gloop_gate_close", gate.global_position + Vector3(9, 2.2, 1.5), gate.global_position + Vector3(0, 2.0, 0))

	# In
	bosses.enter_kingdom()
	await _frames(14)
	var kd := current_scene as Node3D
	p = kd.find_child("Player", true, false) as CharacterBody3D
	var hud := p.get_node("HUD") as CanvasLayer
	hud.visible = false
	_new_cam()
	await _view("03_the_bog_road", Vector3(3, 3.0, -4), Vector3(0, 2.0, 25), 12)
	await _view("04_the_kingdom_from_above", Vector3(-40, 55, -10), Vector3(0, 0, 60), 12)
	await _view("05_the_goo_moat", Vector3(9, 4.5, 36), Vector3(0, 0.8, 49))
	await _view("06_the_palace_gate", Vector3(-7, 4, 50), Vector3(0, 6, 63))
	await _view("07_the_royal_court", Vector3(0, 30, 62), Vector3(0, 0, 92), 10)
	await _view("08_the_king_on_his_throne", Vector3(4, 4.5, 88), Vector3(0, 4.0, 103))
	# The fight, through the game's own camera
	p.global_position = Vector3(0, 1.0, 76)
	await _frames(30)
	var king := kd.get_node("The Gloop King") as CharacterBody3D
	await _physics(80)
	await _view("09_he_hops_down", king.global_position + Vector3(7, 4, -9), king.global_position + Vector3(0, 1.5, 0))
	hud.visible = true
	(p.get_node("SpringArm3D/Camera3D") as Camera3D).make_current()
	p.global_position = king.global_position + Vector3(0, 0.5, -9)
	await _physics(20)
	await _shot("10_the_fight")
	for i in 6:
		king.shot(1, king.global_position, Vector3.FORWARD)
		await _physics(6)
	await _physics(40)
	hud.visible = false
	_new_cam()
	var chest := kd.find_child("Royal Treasure", true, false) as Node3D
	await _view("11_the_royal_treasure", chest.global_position + Vector3(-3, 2.5, -4), chest.global_position + Vector3(0, 0.6, 0), 30)
	_finish()


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

extends SceneTree

# Screenshots of Rhythm Springs as an island (16 Nov 2026): from above, landing on the beach by the pier, the torch
# path up into the valley, the ridge and its waterfall, a lagoon cove, the bamboo grove, the overlook, and the pier
# with its boat. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_rhythm_island.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.rhythm_island_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.rhythm_island_capture_backup.cfg"

var out_dir := "user://rhythm_island_shots"
var cam: Camera3D
var _had_save := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(300.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	_had_save = FileAccess.file_exists(SAVE)
	if _had_save and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var game := root.get_node("Game")
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	root.get_node("Settings").tips = false
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.set_time(3, 11 * 60.0, true)
	change_scene_to_file("res://scenes/portal_worlds/rhythm_springs.tscn")
	for i in 900:
		if current_scene != null and current_scene.name == "RhythmSprings":
			break
		await process_frame
	await _frames(40)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	var hud := s.get_node_or_null("Heat HUD")
	if hud:
		hud.visible = false
	cam = Camera3D.new()
	cam.fov = 55
	cam.far = 900
	s.add_child(cam)
	cam.make_current()
	var g := s.get_node("Ridge/Falls Rock") as Node3D
	var shots := [
		["01_island_from_above", Vector3(0, 120, 150), Vector3(0, 0, 0)],
		["02_from_the_sea", Vector3(40, 14, 140), Vector3(0, 4, 20)],
		["03_landing_on_the_beach", Vector3(-6, 3.2, 72), Vector3(0, 1.5, 40)],
		["04_torch_path_up", Vector3(3, 2.4, 50), Vector3(0, 1.5, 20)],
		["05_ridge_and_waterfall", g.global_position + Vector3(-12, 6, 34), g.global_position + Vector3(0, 7, 0)],
		["06_lagoon_cove", Vector3(-30, 5, 66), Vector3(-42, 0, 50)],
		["07_bamboo_grove", Vector3(-46, 3.0, -10), Vector3(-60, 3, -22)],
		["08_overlook", Vector3(58, 4.5, -4), Vector3(78, 1, -14)],
		["09_pier_and_boat", Vector3(24, 6, 82), Vector3(8, 0, 96)],
		["10_ridge_from_the_valley", Vector3(0, 3, 10), Vector3(0, 8, -60)],
	]
	for sh in shots:
		p.global_position = sh[2] + Vector3(0, 1, 0)
		cam.global_position = sh[1]
		cam.look_at(sh[2], Vector3.UP)
		await _frames(30)
		await _shot(sh[0])
	_finish()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	root.get_node("Game").hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	elif not _had_save:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	quit()

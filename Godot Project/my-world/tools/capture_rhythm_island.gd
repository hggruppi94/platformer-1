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
const B := preload("res://tools/build_rhythm_springs.gd")
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
	var L := preload("res://scripts/rhythm_land.gd")
	var hut: Vector3 = B.LEGEND_HUT
	var ta := deg_to_rad(74.0)
	var tide := Vector3(cos(ta), 0, sin(ta)) * (L.shore_r(ta) - 5.0)
	tide.y = L.height(tide.x, tide.z)
	var bar: Vector3 = B.bar_from()
	var islet: Vector3 = B.islet_at()
	var falls := L.at(B.FALLS_AT, 64.0, 0.0)
	var sea_falls := L.at(B.SEA_FALLS_AT, L.shore_r(deg_to_rad(B.SEA_FALLS_AT)), 6.0)
	var grove_a := L.at(B.GROVE_A, B.GROVE_FROM, B.TERRACE_Y + 1.6)
	var grove_b := L.at(B.GROVE_A, B.GROVE_TO, B.TERRACE_Y + 1.6)
	var hut0: Vector3 = B.HUTS[0]
	var hut1: Vector3 = B.HUTS[1]
	var ov: Vector3 = B.OVERLOOK
	var shots := [
		["01_island_from_above", Vector3(0, 150, 185), Vector3(0, 0, 0)],
		["02_from_the_sea", Vector3(30, 22, 210), Vector3(0, 6, 60)],
		["03_landing_on_the_beach", Vector3(-5, 3.0, 112), Vector3(0, 4.5, 72)],
		["04_torch_path_up", Vector3(1.5, 3.2, 96), Vector3(0, 7.5, 70)],
		["05_big_waterfall", L.at(B.FALLS_AT + 14.0, 36.0, 3.5), falls + Vector3(0, 7, 0)],
		["06_sea_cliffs_and_falls", sea_falls + L.at(B.SEA_FALLS_AT + 55.0, 40.0, 6.0), sea_falls + Vector3(0, 3, 0)],
		["07_bamboo_grove", grove_a + (grove_a - grove_b).normalized() * 2.0, grove_b],
		["08_overlook", ov + Vector3(-14, 4, 10), ov + Vector3(20, -2, -2)],
		["09_pier_and_boat", Vector3(26, 8, 130), Vector3(8, 0, 150)],
		["10_highlands_from_the_valley", Vector3(0, 2.5, 20), Vector3(0, 14, -90)],
		["11_springs_gate", Vector3(0, 8.5, 88), Vector3(0, 9, 70)],
		["12_pavilion", B.PAVILION + Vector3(-14, 5, -10), B.PAVILION + Vector3(0, 2.5, 0)],
		["13_stilt_huts", hut0 + Vector3(18, 9, 14), hut1 + Vector3(0, 5, 0)],
		["14_rope_bridge", hut0 + Vector3(0, 6.6, 0) + (hut1 - hut0).normalized() * -3.0, hut1 + Vector3(0, 5.5, 0)],
		["15_crystal_cave", B.CAVE + B.CAVE.normalized() * -6.0 + Vector3(0, 2.2, 0), B.CAVE + Vector3(0, 1.5, 0)],
		["16_crystal_cave_outside", B.CAVE * 0.55 + Vector3(0, 6, 0), B.CAVE + Vector3(0, 4, 0)],
		["17_flower_glade", B.GLADE + Vector3(-12, 4, -8), B.GLADE + Vector3(0, 1.5, 0)],
		["18_legend_hut", hut + Vector3(8, 3, 8), hut + Vector3(0, 1.5, 0)],
		["19_waterfall_grotto", B.GROTTO * 0.7 + Vector3(0, 3, 0), B.GROTTO + Vector3(0, 3, 0)],
		["20_tide_pools", tide + tide.normalized() * -7.0 + Vector3(4, 3, 0), tide],
		["21_sandbar_to_the_islet", bar - (islet - bar).normalized() * 6.0 + Vector3(2, 4, 0), islet],
		["22_lighthouse_and_headland", ov + Vector3(-60, 20, 70), ov + Vector3(0, 6, 0)],
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

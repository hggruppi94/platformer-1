extends SceneTree

# Screenshots of the 12 Nov 2026 lore changes (tools/test_lore_order.gd checks them): Bramble going home through a
# little crack at 20:30 (scripts/visitor_crack.gd), and the deja vu haze coming home to Stars Hollow from the Void
# (scripts/deja_vu.gd). Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_lore_order.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.lore_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.lore_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"

var out_dir := "user://lore_shots"
var cam: Camera3D
var _had_save := false
var clock: Node


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
	game.hero["name"] = "Sofi"
	root.get_node("Settings").tips = false
	clock = root.get_node("Clock")
	clock.set("pulls_home", false)
	root.get_node("Quests").state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	await _crack()
	await _deja_vu()
	_finish()


func _routine_of(id: String) -> Node:
	for r in current_scene.find_children("*", "", true, false):
		if r.get_script() and str(r.get_script().resource_path).ends_with("scripts/routine.gd") \
				and str(r.get("character_id")) == id:
			return r
	return null


func _crack() -> void:
	# Staged where her evening has her (out in the open), the way scripts/routine.gd does it when she heads home
	clock.on_earth = false
	clock.set_time(clock.day, 19 * 60.0, true)
	game_go(TOWN)
	await _frames(60)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	var bramble := _routine_of("bramble")
	bramble.set_process(false)
	var body := bramble.get_parent() as Node3D
	var at := body.global_position
	p.global_position = at + Vector3(6, 1, 4)
	await create_timer(1.0).timeout
	_cam_in(s)
	_look(at + Vector3(3.6, 2.2, 3.6), at + Vector3(0, 0.7, 0))
	await _shot("01_bramble_heading_home")
	var crack := (load("res://scripts/visitor_crack.gd") as GDScript).call("open", s, at, true) as Node3D
	await create_timer(0.35).timeout
	await _shot("02_a_crack_opens_at_her_feet")
	body.visible = false
	await create_timer(0.25).timeout
	await _shot("03_and_she_drops_through")
	await create_timer(0.6).timeout
	await _shot("04_it_zips_shut")


func _deja_vu() -> void:
	clock.on_earth = true
	clock.earth_minutes = 60.0
	game_go(EARTH)
	await _frames(12)
	await create_timer(0.3).timeout
	await _shot("05_home_again_the_haze")
	await create_timer(1.2).timeout
	await _shot("06_deja_vu")
	await create_timer(3.0).timeout
	await _shot("07_clear_again")


func game_go(path: String) -> void:
	root.get_node("Game").go(path, "", "")


func _cam_in(s: Node) -> void:
	cam = Camera3D.new()
	cam.fov = 55
	s.add_child(cam)
	cam.make_current()


func _look(from: Vector3, to: Vector3) -> void:
	cam.global_position = from
	cam.look_at(to, Vector3.UP)


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

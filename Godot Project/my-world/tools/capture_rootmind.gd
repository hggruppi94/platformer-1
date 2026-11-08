extends SceneTree

# Screenshots of the Rootmind, Bramble's portal world (scripts/rootmind.gd): its portal rising on the Secret Gardens
# hill, the preview window, arriving, the clearing from above, Bramble, the leaf climb, the tall grass, the root
# tunnel, calming the Thornknot, the Rootmind mended, and the watching flowers back in the Void. Opens a window (not
# --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_rootmind.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.rootmind_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.rootmind_capture_backup.cfg"

var out_dir := "user://rootmind_shots"
var cam: Camera3D
var _had_save := false
var portals: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(900.0, true, false, true).timeout.connect(_finish)
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
	portals = root.get_node("Portals")
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.set_time(3, 10 * 60.0, true)
	var quests := root.get_node("Quests")
	quests.state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	quests.state[root.get_node("Remnants").QUEST] = {"step": 0, "done": false, "since_day": 1}
	portals.quakes.append("shard_isle")
	portals.cleared_worlds.append("shard_isle")
	await _void_quake()
	await _inside()
	await _void_after()
	_finish()


func _cam_in(s: Node) -> void:
	cam = Camera3D.new()
	cam.fov = 55
	s.add_child(cam)
	cam.make_current()


func _void_quake() -> void:
	change_scene_to_file("res://scenes/town/town.tscn")
	await _frames(12)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	_cam_in(s)
	var w: Dictionary = portals.world("rootmind")
	var at: Vector3 = root.get_node("Remnants").ground_at(w.at)
	var front := Vector3(sin(w.yaw), 0, cos(w.yaw))
	p.global_position = at + front * 5.0 + Vector3(0, 0.5, 0)
	p.get_node("Visual").rotation.y = w.yaw + PI
	_look(at + front * 12.0 + Vector3(0, 6.0, 0), at + Vector3(0, 1.5, 0))
	await create_timer(portals.QUAKE_DELAY + 1.4).timeout
	await _shot("01_rootmind_portal_rising")
	await create_timer(4.0).timeout
	await _frames(20)
	_look(at + front * 4.5 + Vector3(0, 2.8, 0), at + Vector3(0, 2.6, 0))
	await create_timer(1.5).timeout
	await _shot("02_preview_window")


func _inside() -> void:
	portals.enter("rootmind")
	await _frames(16)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	await create_timer(1.0).timeout
	await _shot("03_arriving_in_the_rootmind")
	p.get_node("HUD").visible = false
	_cam_in(s)
	_look(Vector3(26, 24, 34), Vector3(0, 0, -4))
	await _frames(4)
	await _shot("04_the_clearing_from_above")
	var b := (s.get_node("Bramble") as Node3D).global_position
	p.global_position = b + Vector3(-1.5, 0.5, 2.5)
	_look(b + Vector3(-1.0, 2.0, 4.5), b + Vector3(0, 1.1, 0))
	await _frames(20)
	await _shot("05_bramble_at_home")
	var top := (s.get_node("Bloom1") as Node3D).global_position
	p.global_position = Vector3(-17, 0.5, -1)
	_look(Vector3(-10, 6, 6), top + Vector3(0, -3.5, 0))
	await _frames(20)
	await _shot("06_the_leaf_climb_and_the_high_bloom")
	var m := (s.get_node("Bloom2") as Node3D).global_position
	p.global_position = m + Vector3(-3.0, 0.5, 3.0)
	_look(m + Vector3(-7, 3.0, 8), m + Vector3(0, 1.0, 0))
	await _frames(30)
	await _shot("07_brushing_through_the_tall_grass")
	p.global_position = Vector3(0, 0.5, -19)
	_look(Vector3(0, 1.8, -13.5), Vector3(0, 1.2, -28))
	await _frames(30)
	await _shot("08_the_root_tunnel")
	for i in 3:
		s.get_node("Bloom%d/Spot" % (i + 1)).use()
	await _frames(4)
	_look(Vector3(0, 5, 18), Vector3(0, 1, 0))
	p.global_position = Vector3(1.5, 0.5, 8.0)
	await _frames(10)
	s._t = floor(s._t / s.HIVE_BEAT) * s.HIVE_BEAT + s.HIVE_BEAT + 0.4
	await _frames(3)
	_look(Vector3(2.5, 3.2, 11.5), Vector3(0, 1.0, 0))
	await _shot("09_calming_the_thornknot")
	for n in 3:
		s._t = floor(s._t / s.HIVE_BEAT) * s.HIVE_BEAT + s.HIVE_BEAT + 0.3
		await _frames(2)
		var k: int = s.glowing_knot()
		if k >= 0:
			s.knot_hit(k)
	await create_timer(2.0).timeout
	_look(Vector3(3, 3.5, 10), Vector3(0, 1.2, 0))
	await _shot("10_the_rootmind_mended")
	_look(Vector3(-20, 14, 34), Vector3(0, 4, -6))
	await _frames(4)
	await _shot("11_the_giant_flowers_open")


func _void_after() -> void:
	portals.go_home()
	await _frames(16)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	_cam_in(s)
	var w: Dictionary = portals.world("rootmind")
	var at: Vector3 = root.get_node("Remnants").ground_at(w.at)
	var front := Vector3(sin(w.yaw), 0, cos(w.yaw))
	_look(at + front * 11.0 + Vector3(0, 6.0, 4.0), at + Vector3(-3, 0.8, -4))
	await create_timer(1.5).timeout
	await _shot("12_watching_flowers_in_the_void")


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

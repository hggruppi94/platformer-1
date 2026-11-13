extends SceneTree

# Screenshots of the cracks between worlds (scripts/crack.gd), after Hayden's photo of a real earth fissure (12 Nov
# 2026): Shard Isle's crack in the Void splitting open and from a few sides, looking down into it, the gold way home on
# Shard Isle, and the crack by the old oak on Earth open at midnight and gone at 1 AM; then (13 Nov) jumping into Shard
# Isle's crack mid-tumble and popping up out of the way home on the other side. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_cracks.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.cracks_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.cracks_capture_backup.cfg"

var out_dir := "user://crack_shots"
var cam: Camera3D
var _had_save := false
var portals: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(600.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	_had_save = FileAccess.file_exists(SAVE)
	if _had_save and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	root.get_node("Settings").tips = false
	portals = root.get_node("Portals")
	await _earth()
	await _void()
	await _isle()
	_finish()


func _earth() -> void:
	var game := root.get_node("Game")
	var clock := root.get_node("Clock")
	game.new_game()
	await _wait_for("res://scenes/earth/earth.tscn")
	clock.set_earth_time(23 * 60.0 + 59.7, true)
	await create_timer(4.5).timeout
	var s := current_scene as Node3D
	var crack := s.get("crack") as Node3D
	if crack == null:
		print("no Earth crack")
		return
	var p := s.find_child("Player", true, false) as CharacterBody3D
	_camera(p)
	var c := crack.global_position
	var side := -crack.global_basis.z
	var along := crack.global_basis.x
	p.global_position = c - side * 2.6 + along * 1.5 + Vector3(0, 0.5, 0)
	await _frames(6)
	_look(c - side * 4.5 + along * 5.5 + Vector3(0, 3.6, 0), c + Vector3(0, -0.3, 0))
	await _shot("01_earth_crack_by_the_oak_at_midnight")
	_look(c - along * 8.0 - side * 1.5 + Vector3(0, 2.4, 0), c + Vector3(0, -0.5, 0))
	await _shot("02_earth_crack_along_its_length")
	_look(c - side * 1.6 + Vector3(0, 3.2, 0), c + Vector3(0, -3.0, 0))
	await _shot("03_earth_looking_down_into_it")
	clock.set_earth_time(60.0 + 1.0, true)
	await create_timer(5.0).timeout
	s = current_scene as Node3D
	crack = s.get("crack") as Node3D
	if crack and s.scene_file_path == "res://scenes/earth/earth.tscn":
		p = s.find_child("Player", true, false) as CharacterBody3D
		_camera(p)
		c = crack.global_position
		_look(c + crack.global_basis.z * 4.5 + crack.global_basis.x * 5.5 + Vector3(0, 3.6, 0), c)
		await _shot("04_earth_crack_gone_at_1am")


func _void() -> void:
	var game := root.get_node("Game")
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.set_time(3, 10 * 60.0, true)
	root.get_node("Quests").state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	change_scene_to_file("res://scenes/town/town.tscn")
	await _frames(12)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	_camera(p)
	var w: Dictionary = portals.world("shard_isle")
	var at: Vector3 = root.get_node("Remnants").ground_at(w.at)
	var front := Vector3(sin(w.yaw), 0, cos(w.yaw))
	var along := Vector3(cos(w.yaw), 0, -sin(w.yaw))
	p.global_position = at + front * 6.0 + Vector3(0, 0.5, 0)
	_look(at + front * 11.0 + Vector3(0, 6.0, 0), at)
	await create_timer(portals.QUAKE_DELAY + 0.9).timeout
	await _shot("05_void_crack_splitting_open")
	await create_timer(3.0).timeout
	p.global_position = at + front * 3.4 + along * 2.0 + Vector3(0, 0.5, 0)
	await _frames(6)
	_look(at + front * 9.0 + along * 4.0 + Vector3(0, 4.5, 0), at + Vector3(0, -0.4, 0))
	await _shot("06_void_crack_open")
	_look(at - along * 9.5 + front * 1.5 + Vector3(0, 2.0, 0), at + Vector3(0, -0.4, 0))
	await _shot("07_void_crack_along_its_length")
	_look(at + Vector3(0, 13.0, 0) + front * 0.01, at)
	await _shot("08_void_crack_from_above")
	_look(at + front * 1.5 + Vector3(0, 2.6, 0), at + Vector3(0, -4.0, 0))
	await create_timer(1.0).timeout
	await _shot("09_void_looking_down_at_the_world_below")


func _isle() -> void:
	# Into Shard Isle's crack: the tumble down, from the side
	var g: Node3D = portals.crack("shard_isle")
	var at := g.global_position
	var front := g.global_basis.z
	var along := g.global_basis.x
	_look(at + front * 4.5 + along * 2.5 + Vector3(0, 2.2, 0), at + Vector3(0, -0.6, 0))
	var me := current_scene.find_child("Player", true, false) as CharacterBody3D
	Engine.time_scale = 0.08                 # (slowed right down, so the shot catches the tumble on a slow machine)
	load("res://scripts/crack.gd").drop_player(g)
	for i in 600:                            # (mid-tumble: going down, a bit smaller already)
		await process_frame
		if me.get("carried") == true and (me.get_node("Visual/Tumble") as Node3D).scale.x < 0.97:
			break
	await _shot("11_falling_into_the_crack")
	Engine.time_scale = 1.0
	for i in 300:
		await process_frame
		if current_scene and current_scene.scene_file_path.contains("shard_isle"):
			break
	await _frames(4)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	var home := s.get_node("WayHome") as Node3D
	var loading := root.get_node("Loading")
	for i in 400:
		if not loading.showing:
			break
		await process_frame
	_camera(p)
	var h := home.global_position
	var to := (s.get_node("Entrance") as Node3D).global_position
	var side := (to - h).cross(Vector3.UP).normalized()
	_look((h + to) * 0.5 + side * 9.0 + Vector3(0, 3.0, 0), (h + to) * 0.5 + Vector3(0, 1.8, 0))
	Engine.time_scale = 0.08
	for i in 900:                            # (on the way up, over the ground)
		await process_frame
		if p.get("carried") == true and (p.get_node("Visual") as Node3D).visible and p.global_position.y > h.y + 1.0:
			break
	await _shot("12_popping_out_on_shard_isle")
	Engine.time_scale = 1.0
	await create_timer(1.0).timeout
	var ts := home.global_position
	p.global_position = ts + Vector3(-3.5, 0.5, 3.5)
	_look(ts + Vector3(-5.5, 4.0, 6.0), ts + Vector3(0, -0.5, 0))
	await _frames(6)
	await _shot("10_shard_isle_way_home_crack")


func _camera(p: Node) -> void:
	if p and p.has_node("HUD"):
		p.get_node("HUD").visible = false
	for n in root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false           # (the voice's words, the minimap: just the crack in the shots)
	cam = Camera3D.new()
	cam.fov = 55
	current_scene.add_child(cam)
	cam.make_current()


func _wait_for(path: String) -> void:
	for i in 200:
		await process_frame
		if current_scene and current_scene.scene_file_path == path:
			break
	await _frames(8)


func _look(from: Vector3, to: Vector3) -> void:
	cam.global_position = from
	cam.look_at(to, Vector3.UP)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(file: String) -> void:
	for n in root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false           # (the voice's words, prompts, the minimap: just the crack)
	await _frames(2)
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

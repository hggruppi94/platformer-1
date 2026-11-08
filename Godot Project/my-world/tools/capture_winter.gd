extends SceneTree

# Screenshots of winter in Stars Hollow and Flurry's frost breath: the green with snowmen where the pumpkins were, the
# Snowman Field, the First Snow's snowman with Nina, sledding down Lookout Hill, and ice floes frozen across the
# Void's lake. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_winter.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.winter_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.winter_capture_backup.cfg"

var out_dir := "user://winter_shots"
var cam: Camera3D
var _had_save := false
var portals: Node
var clock: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(240.0, true, false, true).timeout.connect(_finish)
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
	clock = root.get_node("Clock")
	clock.set("pulls_home", false)
	root.get_node("Quests").state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	for w in ["shard_isle", "rootmind", "frozen_moment"]:
		portals.quakes.append(w)
		portals.cleared_worlds.append(w)
	root.get_node("Dialogue").flags["snow_built"] = true
	await _winter_town()
	await _frost()
	_finish()


func _winter_town() -> void:
	clock.on_earth = true
	clock.set_time(clock.day_of("winter", 3, 1), 12 * 60.0, true)
	clock.earth_minutes = 12 * 60.0
	game_go("res://scenes/earth/earth.tscn")
	await _frames(40)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	p.global_position = Vector3(0, 1, 18)
	await create_timer(1.0).timeout
	_cam_in(s)
	_look(Vector3(9, 4.5, 14), Vector3(0, 1.0, 0))
	await _shot("01_the_green_in_winter")
	var patch := s.find_child("Pumpkin Patch", true, false) as Node3D
	_look(patch.global_position + Vector3(0, 6, 14), patch.global_position + Vector3(0, 0.5, 0))
	await _shot("02_the_snowman_field")
	var ours := s.get_node_or_null("First Snow/Our Snowman") as Node3D
	if ours:
		_look(ours.global_position + Vector3(-3.5, 2.0, 4.5), ours.global_position + Vector3(0, 1.0, 0))
		await _shot("03_our_snowman_on_the_green")
	var fs := root.get_node("EarthTown/FirstSnow")
	p.global_position = fs.sled_start() + Vector3(0, 1, 0)
	await _frames(4)
	fs.sled_down()
	await create_timer(2.2).timeout
	_look(p.global_position + Vector3(6, 2.5, 4), p.global_position)
	await _shot("04_sledding_down_lookout_hill")
	await create_timer(2.5).timeout


func _frost() -> void:
	clock.on_earth = false
	clock.set_time(3, 10 * 60.0, true)
	game_go("res://scenes/town/town.tscn")
	await _frames(40)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	var lake: Node = null
	for w in s.get_tree().get_nodes_in_group("water"):
		if w.call("covers", 0.0, 10.0):
			lake = w
	# Out from the lake's middle westwards to the shore (the race arch is on the south shore, in the way)
	var shore := Vector3(0, 0, 10.0)
	while lake.call("covers", shore.x, shore.z):
		shore.x -= 1.0
	p.global_position = shore + Vector3(-1.5, 2.5, 0)
	await create_timer(1.0).timeout
	(p.get_node("Visual") as Node3D).global_rotation.y = PI / 2          # (facing east, over the water)
	var fb := p.get_node("FrostBreath")
	fb.breathe()
	_cam_in(s)
	_look(p.global_position + Vector3(-3.0, 5.5, 3.5), p.global_position + Vector3(5.0, -1.0, 0))
	await create_timer(0.25).timeout
	await _shot("05_frost_breath")
	await create_timer(0.8).timeout
	var last := fb.floes[fb.floes.size() - 1] as Node3D
	p.global_position = last.global_position + Vector3(0, 1.2, 0)
	await create_timer(0.6).timeout
	(p.get_node("Visual") as Node3D).global_rotation.y = PI / 2
	fb.cooldown = 0.0
	fb.breathe()
	await create_timer(0.9).timeout
	_look(p.global_position + Vector3(-6.0, 4.5, 7.0), p.global_position + Vector3(3.0, -0.5, 0))
	await _shot("06_ice_floes_across_the_lake")


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

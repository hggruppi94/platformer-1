extends SceneTree

# Screenshots of the Frozen Moment, Flurry's portal world (scripts/frozen_moment.gd): its portal at the foot of the
# mountains, arriving, Flurry, the three frozen moments, the Frost Gloop frozen and then awake, and the snow falling
# once it's mended. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_frozen_moment.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.frozen_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.frozen_capture_backup.cfg"
const WORLD := "res://scenes/portal_worlds/frozen_moment.tscn"

var out_dir := "user://frozen_shots"
var cam: Camera3D
var _had_save := false
var portals: Node


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
	portals = root.get_node("Portals")
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.set_time(3, 10 * 60.0, true)
	var quests := root.get_node("Quests")
	quests.state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	for w in ["shard_isle", "rootmind"]:
		portals.cleared_worlds.append(w)
		portals.quakes.append(w)
	await _portal()
	await _inside()
	_finish()


func _portal() -> void:
	game_go("res://scenes/town/town.tscn")
	await _frames(16)
	portals.quake("frozen_moment", true)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	var portal := s.get_node("Portals/Portal frozen_moment") as Node3D
	p.global_position = portal.global_position + portal.global_basis.z * 7.0 + Vector3(0, 1, 0)
	await _frames(40)                                         # near enough for the preview window to wake
	_cam_in(s)
	_look(portal.global_position + portal.global_basis.z * 10.0 + Vector3(3.5, 3.0, 0), portal.global_position + Vector3(0, 2.6, 0))
	await _frames(30)
	await _shot("01_portal_by_the_mountains")


func _inside() -> void:
	portals.enter("frozen_moment")
	await _frames(20)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	_cam_in(s)
	await _frames(10)
	_look(Vector3(-3.0, 3.2, 36.0), Vector3(0, 6.0, -12.0))
	await _shot("02_arriving_time_has_stopped")
	var f := (s.get_node("Flurry") as Node3D).global_position
	p.global_position = f + Vector3(1.0, 0.9, 2.4)
	await create_timer(1.2).timeout                          # she turns to look at you
	_look(f + Vector3(-1.6, 1.4, 2.6), f + Vector3(0, 0.75, 0))
	await _shot("03_flurry")
	var m1 := (s.get_node("Moment1") as Node3D).global_position
	p.global_position = m1 + Vector3(-2.5, 0.9, 2.5)
	await _frames(6)
	_look(m1 + Vector3(-3.5, 2.4, 4.5), m1 + Vector3(0, 1.1, 0))
	await _shot("04_frozen_fish_on_the_lake")
	var m2 := (s.get_node("Moment2") as Node3D).global_position
	p.global_position = m2 + Vector3(0, 0.9, 2.6)
	await _frames(6)
	_look(m2 + Vector3(1.5, 3.0, 7.0), m2 + Vector3(0, 1.3, 0))
	await _shot("05_snowball_fight_on_the_hill")
	var m3 := (s.get_node("Moment3") as Node3D).global_position
	p.global_position = m3 + Vector3(-4.0, 0.9, 0.8)
	await _frames(6)
	_look(m3 + Vector3(-8.0, 2.6, 1.6), m3 + Vector3(0, 1.8, 0))
	await _shot("06_snowbird_in_the_icicle_cave")
	var g := (s.get_node("FrostGloop") as Node3D).global_position
	p.global_position = Vector3(0, 0.9, 20)
	await _frames(4)
	_look(g + Vector3(5.0, 3.5, 9.0), g + Vector3(0, 1.0, 0))
	await _shot("07_frost_gloop_frozen_on_its_throne")
	for i in 3:
		for k in 3:
			s.get_node("Moment%d/Spot" % (i + 1)).use()
	await create_timer(4.5).timeout
	await _shot("08_moments_thawed")
	p.global_position = g + Vector3(0, 0.9, 12)
	await _frames(4)
	var gloop := s._gloop as Node3D
	p.global_position = g + Vector3(-6, 0.9, 13)
	await create_timer(1.6).timeout
	_look(gloop.global_position + Vector3(4.5, 3.0, 8.0), gloop.global_position + Vector3(0, 1.4, 0))
	await _shot("09_frost_gloop_awake")
	p.global_position = Vector3(0, 0.9, 22)
	for i in 6:
		gloop.shot(1, gloop.global_position, Vector3.FORWARD)
	await create_timer(5.0).timeout
	_look(Vector3(6.0, 2.6, 22.0), Vector3(-2.0, 7.0, -30.0))
	await _shot("10_mended_snow_falling")


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

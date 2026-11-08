extends SceneTree

# Screenshots of the Frozen Moment's reward (plan item 20 and the Frozen Moment, slice two): the Calendar with winter
# still frosted over, then after mending it the calendar's winter page and Stars Hollow under snow, and Flurry on the
# Portal Plaza in the Void in her own little snowfall. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_season_unlocks.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.season_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.season_capture_backup.cfg"

var out_dir := "user://season_shots"
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
	var quests := root.get_node("Quests")
	quests.state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	clock.seasons_open = ["autumn"]
	for w in ["shard_isle", "rootmind", "frozen_moment"]:
		portals.quakes.append(w)
	for w in ["shard_isle", "rootmind"]:
		portals.cleared_worlds.append(w)
	await _calendar("01_calendar_winter_frosted", 1)
	portals.cleared_worlds.append("frozen_moment")
	portals.open_seasons()
	await _calendar("02_calendar_winter_unlocked", 1)
	await _flurry()
	await _snowy_town()
	_finish()


func _calendar(file: String, page: int) -> void:
	game_go("res://scenes/earth/earth.tscn")
	await _frames(20)
	clock.set_time(1, 14 * 60.0, true)
	var menu := root.get_node("PlayerMenu")
	menu.open("calendar")
	await _frames(4)
	for i in page:
		(menu._body.find_child("Cal next", true, false) as Button).pressed.emit()
		await _frames(4)
	await _shot(file)
	menu.close()
	await _frames(2)


func _flurry() -> void:
	clock.on_earth = false
	clock.set_time(3, 10 * 60.0, true)
	game_go("res://scenes/town/town.tscn")
	await _frames(30)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	var f := s.get_node("Portals/Flurry") as Node3D
	p.global_position = f.global_position + f.global_basis.z * 2.6 + f.global_basis.x * -2.2 + Vector3(0, 1, 0)
	await create_timer(1.5).timeout
	_cam_in(s)
	_look(f.global_position + f.global_basis.z * 3.0 + f.global_basis.x * -0.6 + Vector3(0, 1.3, 0), f.global_position + Vector3(0, 0.75, 0))
	await _shot("03_flurry_on_the_portal_plaza")
	var plaza := s.get_node("Portals/Portal Plaza") as Node3D
	_look(plaza.global_position + plaza.global_basis.z * 11.0 + Vector3(0, 4.0, 0), plaza.global_position + Vector3(0, 1.6, 0))
	await _shot("04_the_plaza_with_flurry")


func _snowy_town() -> void:
	clock.on_earth = true
	clock.set_time(clock.day_of("winter", 3, 1), 13 * 60.0, true)
	clock.earth_minutes = 13 * 60.0
	game_go("res://scenes/earth/earth.tscn")
	await _frames(40)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	await create_timer(1.2).timeout
	_cam_in(s)
	_look(p.global_position + Vector3(6, 5, 10), p.global_position + Vector3(0, 1.5, -6))
	await _shot("05_winter_comes_to_stars_hollow")


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

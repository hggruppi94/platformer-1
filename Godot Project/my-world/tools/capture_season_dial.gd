extends SceneTree

# Screenshots of the Season Dial by the old oak (scripts/season_dial.gd): with only winter opened (spring and summer
# frosted over), close up, the question it asks, the pointer spinning and the colour wash, then Stars Hollow in winter
# and, with all four open, in spring and summer. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_season_dial.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.dial_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.dial_capture_backup.cfg"

var out_dir := "user://dial_shots"
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
	await _dial()
	_finish()


func _dial() -> void:
	clock.seasons_open = ["autumn", "winter"]
	clock.calendar_offset = clock.CALENDAR_START
	clock.on_earth = true
	clock.set_time(clock.day_of("autumn", 10, 1), 11 * 60.0, true)
	clock.earth_minutes = 11 * 60.0
	game_go("res://scenes/earth/earth.tscn")
	await _frames(40)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	var g := s.get_node("Season Dial") as Node3D
	var front := Vector3(0, 0, 1).rotated(Vector3.UP, g.rotation.y)
	var side := Vector3(1, 0, 0).rotated(Vector3.UP, g.rotation.y)
	var at := g.global_position
	p.global_position = at + front * 2.2 + side * 0.8 + Vector3(0, 0.85, 0)
	p.get_node("Visual").rotation.y = g.rotation.y + PI
	await create_timer(1.0).timeout
	_cam_in(s)
	_look(at + front * 6.0 + side * 3.0 + Vector3(0, 3.0, 0), at + Vector3(0, 1.5, -2.0))
	await _shot("01_the_season_dial_by_the_old_oak")
	_look(at + front * 1.6 + Vector3(0, 2.0, 0), at + Vector3(0, 1.0, 0))
	await _shot("02_close_up_spring_and_summer_frosted_over")
	var dial := root.get_node("EarthTown/SeasonDial")
	var dialogue := root.get_node("Dialogue")
	p.get_node("HUD").visible = true
	_look(at + front * 4.0 + side * 1.5 + Vector3(0, 2.2, 0), at + Vector3(0, 1.0, 0))
	dial.ask()
	for k in 6:
		if not dialogue.current_choices().is_empty():
			break
		dialogue._finish_typing()
		dialogue._next()
	await create_timer(0.6).timeout
	await _shot("03_which_season")
	var answers: Array = dialogue.current_choices()
	if not answers.is_empty():
		(answers[0] as Button).pressed.emit()
	if dialogue.is_active():
		dialogue.end()
	p.get_node("HUD").visible = false
	_look(at + front * 1.6 + Vector3(0, 2.0, 0), at + Vector3(0, 1.0, 0))
	await create_timer(0.9).timeout
	await _shot("04_the_pointer_spins")
	await create_timer(0.9).timeout
	await _shot("05_washing_over_into_winter")
	var t := 0.0
	while dial.turns == 0 and t < 6.0:
		await process_frame
		t += 0.016
	await _frames(40)
	await create_timer(1.5).timeout
	s = current_scene as Node3D
	p = s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	_cam_in(s)
	_look(at + front * 7.0 + side * 4.0 + Vector3(0, 3.5, 0), at + Vector3(0, 1.2, -2.0))
	await _shot("06_winter_in_stars_hollow")
	# All four open: spring, then summer
	clock.seasons_open = clock.SEASONS.duplicate()
	for season in ["spring", "summer"]:
		dial.turn_to(season, true)
		var n0: int = dial.turns
		t = 0.0
		while dial.turns == n0 and t < 6.0:
			await process_frame
			t += 0.016
		await _frames(40)
		await create_timer(1.5).timeout
		s = current_scene as Node3D
		p = s.find_child("Player", true, false) as CharacterBody3D
		p.get_node("HUD").visible = false
		_cam_in(s)
		_look(at + front * 1.8 + side * 0.6 + Vector3(0, 2.0, 0), at + Vector3(0, 1.0, 0))
		await _shot("%02d_%s_on_the_dial" % [7 if season == "spring" else 9, season])
		_look(at + front * 7.0 + side * 4.0 + Vector3(0, 3.5, 0), at + Vector3(0, 1.2, -2.0))
		await _shot("%02d_%s_in_stars_hollow" % [8 if season == "spring" else 10, season])


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

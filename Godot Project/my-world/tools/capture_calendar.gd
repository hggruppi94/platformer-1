extends SceneTree

# Screenshots of Earth's calendar (scripts/clock.gd): the Calendar sheet in the Tab menu (this season and the next),
# the date on the HUD, the kids out round town on a Saturday morning instead of at school, then Stars Hollow in each
# season (scripts/seasons.gd) from the same four places, snow falling, summer fireflies, the Frost, Spring and Summer
# fairs (scripts/festival.gd) and Hallow's Eve on Maple Lane.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_calendar.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.calendar_capture_backup.json"
const EARTH := "res://scenes/earth/earth.tscn"

var out_dir := "user://calendar_shots"
var cam: Camera3D
var game: Node
var clock: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(600.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	game = root.get_node("Game")
	clock = root.get_node("Clock")
	root.get_node("Settings").tips = false
	root.get_node("Dialogue").reset()
	root.get_node("Quests").reset()
	game.needs_creator = false
	game._resume = {}
	game.riding = false
	game.pending_message = ""
	clock.pulls_home = false
	clock.reset()
	clock.day = 2                                              # Saturday 20 Autumn: no school, festival tonight
	change_scene_to_file(EARTH)
	await _wait_for_scene(EARTH)
	clock.set_earth_time(10 * 60.0 + 30.0, true)
	clock.jumped.emit()
	await _frames(30)

	# --- The kids at the skate yard on a Saturday morning ---
	var yard := _place("skate_yard")
	_player().global_position = yard + Vector3(8, 1, 8)
	_make_cam()
	cam.global_position = yard + Vector3(9, 5, 11)
	cam.look_at(yard + Vector3(0, 1, 0))
	await _shot("01_saturday_morning_no_school_skate_yard", 40)
	cam.queue_free()
	cam = null

	# --- The date on the HUD, then the Calendar sheet ---
	_player().global_position = Vector3(6.0, 1.0, 16.0)
	await _shot("02_the_date_on_the_hud", 20)
	var menu := root.get_node("PlayerMenu")
	menu.open("calendar")
	await _shot("03_calendar_this_season", 10)
	(menu._body.find_child("Cal next", true, false) as Button).pressed.emit()
	await _shot("04_calendar_next_season_winter", 10)
	(menu._body.find_child("Cal next", true, false) as Button).pressed.emit()
	await _shot("05_calendar_spring_break", 10)
	menu.close()

	# --- The seasons in Stars Hollow (scripts/seasons.gd): the same views in each ---
	var seasons := current_scene.get_node("Seasons")
	var n := 6
	for season in ["autumn", "winter", "spring", "summer"]:
		clock.day = clock.day_of(season, 9)                    # a Tuesday: school's on, nobody's at a festival
		clock.set_earth_time(13 * 60.0, true)
		clock.jumped.emit()
		seasons.apply(season)
		_player().global_position = Vector3(30, 1, 30)
		_make_cam()
		for view in [["the_green", Vector3(26, 16, 34), Vector3(0, 2, 0)],
				["willow_pond", Vector3(-62, 9, 40), Vector3(-85, 0, 18)],
				["main_street", Vector3(0, 7, -24), Vector3(0, 3, -70)],
				["lookout_hill", Vector3(-70, 14, -60), Vector3(-110, 5, -100)]]:
			cam.global_position = view[1]
			cam.look_at(view[2])
			_player().global_position = view[1] + Vector3(0, -3, 0)
			await _shot("%02d_%s_%s" % [n, season, view[0]], 30)
			n += 1
		cam.queue_free()
		cam = null
	# Snow falling, close up, and summer fireflies at night
	clock.day = clock.day_of("winter", 9)
	seasons.apply("winter")
	clock.set_earth_time(16 * 60.0 + 30.0, true)
	_player().global_position = Vector3(6.0, 1.0, 16.0)
	_make_cam()
	cam.global_position = Vector3(9, 3.2, 24)
	cam.look_at(Vector3(0, 2.5, 0))
	await _shot("%02d_winter_snow_falling" % n, 60)
	n += 1
	clock.day = clock.day_of("summer", 9)
	seasons.apply("summer")
	clock.set_earth_time(22 * 60.0, true)
	await _shot("%02d_summer_night_fireflies" % n, 60)
	n += 1
	cam.queue_free()
	cam = null

	# --- The fairs (scripts/festival.gd) and Hallow's Eve ---
	for f in [["winter", 17, "frost_fair"], ["spring", 18, "spring_fair"], ["summer", 19, "summer_fair"]]:
		clock.day = clock.day_of(f[0], 6)                     # a Saturday
		seasons.apply(f[0])
		clock.set_earth_time(f[1] * 60.0 + 20.0, true)
		_player().global_position = Vector3(0, 1, 18)
		await _frames(60)                                      # (Festival puts the fair up within half a second)
		_make_cam()
		cam.global_position = Vector3(0, 6.5, 24)
		cam.look_at(Vector3(0, 1.5, 4))
		await _shot("%02d_%s" % [n, f[2]], 40)
		n += 1
		cam.global_position = Vector3(7, 2.6, -2)
		cam.look_at(Vector3(9.5, 1.2, -1.6))
		await _shot("%02d_%s_barrel_game" % [n, f[2]], 20)
		n += 1
		cam.queue_free()
		cam = null
	clock.day = 10                                             # Sunday 28 Autumn: Hallow's Eve
	seasons.apply("autumn")
	clock.set_earth_time(19 * 60.0, true)
	await _frames(60)
	var door := _place("palmer_house")
	_player().global_position = door + Vector3(0, 1, 2.5)
	_make_cam()
	cam.global_position = door + Vector3(6, 3.5, 7)
	cam.look_at(door + Vector3(-6, 1, 0))
	await _shot("%02d_hallows_eve_maple_lane" % n, 50)
	_finish()


func _place(name: String) -> Vector3:
	var paths := TownPaths.get_shared(TownPaths.EARTH_FILE)
	var p: Vector2 = paths.points[name]
	return Vector3(p.x, EarthLand.height(p.x, p.y), p.y)


func _make_cam() -> void:
	cam = Camera3D.new()
	cam.fov = 65.0
	current_scene.add_child(cam)
	cam.make_current()


func _player() -> CharacterBody3D:
	return current_scene.find_child("Player", true, false) as CharacterBody3D


func _shot(file: String, settle := 8) -> void:
	for i in settle:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _wait_for_scene(path: String, frames := 200) -> void:
	for i in frames:
		await process_frame
		if current_scene and current_scene.scene_file_path == path:
			break
	await _frames(6)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit()

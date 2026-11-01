extends SceneTree

# Screenshots of Stars Hollow's big days (scripts/festival.gd BIG_DAYS, scripts/big_day.gd): the Winter Tree before and
# after it's lit, Kite Day over Lookout Hill (and the player's own kite), and the Firefly Night fireworks over Willow
# Pond. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_big_days.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.big_days_capture_backup.json"
const EARTH := "res://scenes/earth/earth.tscn"

var out_dir := "user://big_day_shots"
var cam: Camera3D
var game: Node
var clock: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(400.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	game = root.get_node("Game")
	clock = root.get_node("Clock")
	var F := root.get_node("Festival")
	root.get_node("Settings").tips = false
	root.get_node("Dialogue").reset()
	root.get_node("Quests").reset()
	F.reset()
	game.needs_creator = false
	game._resume = {}
	game.riding = false
	game.pending_message = ""
	clock.pulls_home = false
	clock.reset()
	clock.day = clock.day_of("winter", 21)
	clock.set_earth_time(17 * 60.0 + 30.0, true)
	change_scene_to_file(EARTH)
	await _wait_for_scene(EARTH)
	var seasons := current_scene.get_node("Seasons")
	seasons.apply("winter")
	var tree := Vector3(F.TREE_AT.x, EarthLand.height(F.TREE_AT.x, F.TREE_AT.y), F.TREE_AT.y)
	_player().global_position = tree + Vector3(5, 1, 6)
	await _frames(40)
	_make_cam()
	cam.global_position = tree + Vector3(9, 4.5, 11)
	cam.look_at(tree + Vector3(0, 3.2, 0))
	await _shot("01_winter_lights_before", 30)
	clock.set_earth_time(18 * 60.0 + 10.0, true)
	await _shot("02_winter_lights_lit", 60)
	cam.global_position = tree + Vector3(4, 2.2, 5)
	cam.look_at(tree + Vector3(0, 3.5, 0))
	await _shot("03_winter_tree_close", 20)
	cam.queue_free()
	cam = null

	clock.day = clock.day_of("spring", 14)
	seasons.apply("spring")
	clock.set_earth_time(11 * 60.0, true)
	clock.jumped.emit()
	await _frames(40)
	var show := current_scene.get_node("Big Day")
	var top: Vector3 = show._hilltop()
	F.kite_day = clock.earth_day()
	_player().global_position = top + Vector3(3, 1, 6)
	await _frames(90)
	_make_cam()
	cam.global_position = top + Vector3(22, 10, 26)
	cam.look_at(top + Vector3(0, 9, 0))
	await _shot("04_kite_day_lookout_hill", 60)
	cam.global_position = _player().global_position + Vector3(4, 2.5, 8)
	cam.look_at(_player().global_position + Vector3(-2, 6, 3))
	await _shot("05_kite_day_your_kite", 20)
	var stand := Vector3(F.KITE_STAND_AT.x, EarthLand.height(F.KITE_STAND_AT.x, F.KITE_STAND_AT.y), F.KITE_STAND_AT.y)
	cam.global_position = stand + Vector3(3, 2.2, 4)
	cam.look_at(stand + Vector3(0, 1.2, 0))
	await _shot("06_kite_stand", 20)
	cam.queue_free()
	cam = null

	clock.day = clock.day_of("summer", 28)
	seasons.apply("summer")
	clock.set_earth_time(21 * 60.0 + 30.0, true)
	clock.jumped.emit()
	_player().global_position = Vector3(-62, 1, 2)
	await _frames(60)
	_make_cam()
	cam.global_position = Vector3(-52, 2, -14)
	cam.look_at(Vector3(-85, 30, 20))
	await create_timer(3.0).timeout                          # (rockets need a second or so to climb and burst)
	await _shot("07_firefly_night_fireworks", 2)
	clock.set_earth_time(22 * 60.0 + 2.0, true)
	await create_timer(2.6).timeout
	await _shot("08_firefly_night_finale", 2)
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

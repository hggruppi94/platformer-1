extends SceneTree

# Pictures of Stars Hollow's rolling hills (EarthLand.ROLLS) and the countryside rolling up past the walls
# (EarthLand.country()): the east fields, the meadow north of the creek path, the hills west of the creek and behind
# Maple Lane's gardens, the town in its valley from above and from Lookout Hill, skating over a roll, and the map.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_earth_hills.gd -- <output folder> [only]
#
# Pass a shot's name (or part of it) as "only" to take just that one. Your own save is put aside and put back.

const SAVE := "user://save.json"
const BACKUP := "user://save.earth_hills_backup.json"
const EARTH := "res://scenes/earth/earth.tscn"

var out_dir := "user://earth_hills_shots"
var only := ""
var cam: Camera3D
var clock: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		only = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	create_timer(300.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	clock = root.get_node("Clock")
	root.get_node("Dialogue").reset()
	root.get_node("Quests").reset()
	root.get_node("Settings").tips = false
	game._resume = {}
	game.pending_message = ""
	game.next_spawn = "Entrance"
	game.riding = false
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	clock.day = 4                                                 # a Monday, so no festival on the green
	clock.earth_minutes = 11 * 60.0
	change_scene_to_file(EARTH)
	for i in 8:
		await process_frame
	await create_timer(1.5).timeout
	var player := current_scene.find_child("Player", true, false) as CharacterBody3D
	(player.get_node("HUD") as CanvasLayer).visible = false
	player.global_position = Vector3(0, 1, -60)
	cam = Camera3D.new()
	cam.far = 1500.0
	current_scene.add_child(cam)
	cam.make_current()
	await _at("01_the_east_fields_from_above", Vector3(30, 22, 12), Vector3(74, 0, -70), 10.5)
	await _at("02_rolling_down_the_east_fields", Vector3(62, 3.0, 14), Vector3(72, 2.5, -60), 11)
	await _at("03_the_meadow_north_of_the_creek", Vector3(-24, 5, -112), Vector3(-50, 2, -140), 15)
	await _at("04_hills_west_of_the_creek", Vector3(-112, 4.5, 6), Vector3(-138, 2, -30), 16)
	await _at("05_behind_maple_lane", Vector3(10, 9, 62), Vector3(50, 1, 94), 16.5)
	await _at("06_the_town_in_its_valley", Vector3(70, 60, 140), Vector3(-30, 0, -40), 17.2)
	await _at("07_town_from_the_hill_at_dusk", Vector3(-104, 10, -94), Vector3(0, 0, -20), 18.4)
	await _at("08_the_countryside_from_lookout_hill", Vector3(-108, 9.5, -104), Vector3(-260, 10, -230), 17.0)
	await _at("09_the_countryside_past_the_east_wall", Vector3(80, 8, -100), Vector3(260, 14, -80), 12)
	await _ride(player)
	await _map(player)
	_finish()


func _ride(player: CharacterBody3D) -> void:
	# On a board, cresting the biggest roll in the east fields
	if only != "" and not "10_skating_over_a_roll".contains(only):
		return
	_set_hour(15.5)
	var r: Vector4 = EarthLand.ROLLS[1]
	player.global_position = Vector3(r.x + 3.0, EarthLand.height(r.x + 3.0, r.y) + 0.4, r.y)
	player.set_rider("hero")
	await create_timer(0.8).timeout
	var at := player.global_position
	cam.global_position = at + Vector3(7, 1.2, 6)
	cam.look_at(at + Vector3(-4, 0.6, -6))
	await create_timer(0.3).timeout
	await _shot("10_skating_over_a_roll")


func _map(player: Node3D) -> void:
	# The map sheet, with the rolling hills drawn as soft humps
	if only != "" and not "11_the_map".contains(only):
		return
	_set_hour(12)
	cam.current = false
	(player.get_node("HUD") as CanvasLayer).visible = true
	await create_timer(0.6).timeout
	root.get_node("PlayerMenu").toggle_sheet("map")
	await create_timer(0.6).timeout
	await _shot("11_the_map")
	root.get_node("PlayerMenu").toggle_sheet("map")


func _at(file: String, from: Vector3, look: Vector3, hour: float) -> void:
	if only != "" and not file.contains(only):
		return
	_set_hour(hour)
	cam.global_position = from
	cam.look_at(look)
	await create_timer(0.6).timeout
	await _shot(file)


func _set_hour(hour: float) -> void:
	clock.earth_minutes = hour * 60.0
	clock.time_changed.emit()
	if current_scene.has_method("_light"):
		current_scene.call("_light")


func _shot(file: String) -> void:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()

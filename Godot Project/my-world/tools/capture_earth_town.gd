extends SceneTree

# Screenshots of the grown-up Earth town (tools/build_earth.gd): from the corner of the green, Main Street by day,
# the park with the pond, the creek and the covered bridge, Mossy Falls and Lookout Hill, the Hollow Skate Yard,
# inside the bakery, the toy shop, the library and the Blastoffs' house, Maple Lane, and the town at night. Opens a
# window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_earth_town.gd -- <output folder> [only]
#
# Pass a shot's name (or part of it) as "only" to take just that one. Your own save is put aside and put back.

const SAVE := "user://save.json"
const BACKUP := "user://save.earth_town_backup.json"
const EARTH := "res://scenes/earth/earth.tscn"

var out_dir := "user://earth_town_shots"
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
	game._resume = {}
	game.pending_message = ""
	game.next_spawn = "Entrance"
	clock.earth_minutes = 11 * 60.0
	change_scene_to_file(EARTH)
	for i in 8:
		await process_frame
	await create_timer(1.5).timeout
	var player := current_scene.find_child("Player", true, false) as Node3D
	(player.get_node("HUD") as CanvasLayer).visible = false
	cam = Camera3D.new()
	cam.far = 1500.0
	current_scene.add_child(cam)
	cam.make_current()
	await _at("01_from_the_corner_of_the_green", Vector3(-26, 6, 26), Vector3(0, 2, -10), 11)
	await _at("02_main_street_by_day", Vector3(-2, 3.2, -30), Vector3(0, 2.5, -95), 11)
	await _at("03_main_street_from_above", Vector3(-30, 32, -30), Vector3(0, 0, -85), 14)
	await _at("04_the_park_and_willow_pond", Vector3(-48, 9, 22), Vector3(-90, 0, -8), 15)
	await _at("05_the_covered_bridge", Vector3(-88, 4, 48), Vector3(-103, 2, 58), 16)
	await _at("06_mossy_falls", Vector3(-96, 4, -62), Vector3(-106, 3, -83), 15)
	await _at("07_lookout_hill_big_air_run", Vector3(-58, 5, -88), Vector3(-100, 4, -97), 15)
	await _at("08_hollow_skate_yard", Vector3(4, 12, -76), Vector3(30, 1, -104), 13)
	await _at("09_big_vert", Vector3(30, 3, -96), Vector3(30, 3, -112), 13)
	await _at("10_maple_lane", Vector3(-20, 5, 52), Vector3(-60, 2, 64), 16)
	await _inside("11_inside_the_bakery", "Bakery", 12)
	await _inside("12_inside_the_toy_shop", "Toy Shop", 12)
	await _inside("13_inside_the_library", "Library", 12)
	await _inside("14_inside_the_town_hall", "Earth Town Hall", 12)
	await _inside("15_inside_the_blastoffs_house", "Blastoff House", 12)
	await _at("16_library_steps_handrails", Vector3(-1, 2.2, -90), Vector3(-9, 1, -84), 12)
	await _at("17_dusk_on_main_street", Vector3(-2, 3.2, -30), Vector3(0, 2.5, -95), 18.6)
	await _at("18_the_green_at_night", Vector3(-26, 6, 26), Vector3(0, 2, -10), 21.5)
	await _at("19_the_park_at_night", Vector3(-48, 9, 22), Vector3(-90, 0, -8), 21.5)
	await _at("20_town_from_the_hill_at_dusk", Vector3(-104, 10, -94), Vector3(0, 0, -20), 18.4)
	await _map(player)
	_finish()


func _map(player: Node3D) -> void:
	# The map sheet and the corner minimap, with her on Main Street
	if only != "" and not "21_the_earth_map".contains(only) and not "22_the_minimap".contains(only):
		return
	_set_hour(12)
	cam.current = false
	player.global_position = Vector3(0, 1.0, -60)
	(player.get_node("HUD") as CanvasLayer).visible = true
	await create_timer(0.6).timeout
	root.get_node("Settings").minimap = true
	await _shot("22_the_minimap")
	root.get_node("PlayerMenu").toggle_sheet("map")
	await create_timer(0.6).timeout
	await _shot("21_the_earth_map")
	root.get_node("PlayerMenu").toggle_sheet("map")
	root.get_node("Settings").minimap = false


func _at(file: String, from: Vector3, look: Vector3, hour: float) -> void:
	if only != "" and not file.contains(only):
		return
	_set_hour(hour)
	cam.global_position = from
	cam.look_at(look)
	await create_timer(0.6).timeout
	await _shot(file)


func _inside(file: String, building: String, hour: float) -> void:
	# From the doorway's side of the room, looking in toward the back
	if only != "" and not file.contains(only):
		return
	var b := current_scene.find_child(building, true, false) as Node3D
	var inside := b.get_node("Inside") as Node3D
	var door := b.get_node("Doorway") as Node3D
	_set_hour(hour)
	var into := (inside.global_position - door.global_position)
	into.y = 0.0
	cam.global_position = door.global_position + into.normalized() * 3.4 + Vector3(0, 1.4, 0)
	cam.look_at(inside.global_position + into.normalized() * 3.0 + Vector3(0, 0.2, 0))
	cam.fov = 80.0
	await create_timer(0.6).timeout
	await _shot(file)
	cam.fov = 75.0


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

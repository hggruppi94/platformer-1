extends SceneTree

# Pictures for the lighting levels (23 Nov 2026, scripts/world_light.gd): each view three times from the same spot,
# Simple (the old look), Nice and Best, so they make a before and after.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_world_light.gd -- <folder> [earth|void|rooms]...
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.light_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.light_capture_backup.cfg"
const EARTH := "res://scenes/earth/earth.tscn"
const TOWN := "res://scenes/town/town.tscn"
const ROOM := "res://scenes/interiors/town_hall.tscn"
const LEVELS := ["simple", "nice", "best"]

# name: [eye, look at, hour]
const EARTH_VIEWS := [
	["01_earth_green", Vector3(9.0, 1.7, 11.0), Vector3(0, 2.6, 0), 11.0],
	["02_earth_bench_gazebo", Vector3(9.5, 1.3, 7.6), Vector3(5.6, 0.6, 3.6), 11.0],
	["03_earth_main_street", Vector3(-1.5, 1.7, -32), Vector3(0, 2.2, -80), 15.0],
	["04_earth_golden_hour", Vector3(-14, 2.0, 16), Vector3(6, 3.5, -4), 18.2],
	["05_earth_dusk", Vector3(12, 2.2, 14), Vector3(-2, 2.5, -2), 18.9],
	["06_earth_night", Vector3(9.0, 1.7, 11.0), Vector3(0, 2.6, 0), 21.5],
	["07_earth_over_town", Vector3(0, 30, 60), Vector3(0, 0, -10), 17.6],
]
const VOID_VIEWS := [
	["11_void_market", Vector3(-40, 4, 70), Vector3(-30, 2, 30), 11.0],
	["12_void_lake", Vector3(0, 9, 30), Vector3(0, 0, -8), 11.0],
	["13_void_evening", Vector3(-40, 4, 70), Vector3(-30, 2, 30), 18.5],
	["14_void_night", Vector3(-40, 4, 70), Vector3(-30, 2, 30), 22.0],
	["15_void_over_town", Vector3(0, 40, 90), Vector3(0, 0, 0), 16.0],
]
const ROOM_VIEWS := [
	["21_town_hall", Vector3(0, 2.2, 8), Vector3(0, 1.6, -4), 11.0],
]

var out_dir := "user://light_shots"
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not args[0].begins_with("--"):
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	create_timer(3000.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var args := OS.get_cmdline_user_args()
	var which := []
	for a in ["earth", "void", "rooms"]:
		if a in args:
			which.append(a)
	if which.is_empty():
		which = ["earth", "void", "rooms"]
	var game := root.get_node("Game")
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Settings").tips = false
	root.get_node("Settings").minimap = false
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	if "earth" in which:
		clock.on_earth = true
		clock.set_earth_time(11 * 60.0, true)
		await _place(EARTH)
		for v in EARTH_VIEWS:
			clock.set_earth_time(v[3] * 60.0, true)
			await _three(v)
	if "void" in which:
		clock.on_earth = false
		clock.set_time(3, 11 * 60.0, true)
		await _place(TOWN)
		for v in VOID_VIEWS:
			clock.set_time(3, v[3] * 60.0, true)
			await _three(v)
	if "rooms" in which:
		await _place(ROOM)
		for v in ROOM_VIEWS:
			await _three(v)
	_finish()


func _place(path: String) -> void:
	change_scene_to_file(path)
	for i in 16:
		await process_frame
	await create_timer(3.5).timeout
	var lw := current_scene.get_node_or_null("Mesh LODs")
	while lw and lw.busy():
		await process_frame
	var player := current_scene.find_child("Player", true, false) as Node3D
	if player:
		player.global_position += Vector3(0, -40, 0)            # out of the shots
		player.visible = false
		player.process_mode = Node.PROCESS_MODE_DISABLED
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	cam = Camera3D.new()
	cam.fov = 60
	cam.far = 3000
	current_scene.add_child(cam)
	cam.make_current()


func _three(v: Array) -> void:
	var light := current_scene.get_node_or_null("World Light")
	cam.make_current()
	cam.global_position = v[1]
	cam.look_at(v[2])
	for level in LEVELS:
		if light:
			light.set_level(level)
		await _shot("%s_%s" % [v[0], level])


func _shot(file: String) -> void:
	# Long enough for the haze's temporal smoothing to settle
	for i in 24:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	else:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	else:
		DirAccess.remove_absolute(SETTINGS)
	quit()

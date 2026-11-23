extends SceneTree

# Pictures for the Clockwork Tower's baked props: the gears, the Pendulum Walk's gear walls and pendulums, the Cog
# Gate, the tower's round wall, the Big Clock, Tock's dais, the Cuckoo Chest and the rail posts (23 Nov 2026,
# tools/build_prop_clock_tower.py, scripts/detail_props.gd dress_clock_tower()). With --old-props it shoots the same
# spots with everything the pipeline adds turned off, so the two sets make a before and after.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_detail_clock_tower.gd -- <folder> [--old-props]
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.detail_clock_tower_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.detail_clock_tower_capture_backup.cfg"
const WORLD := "res://scenes/bosses/clock_tower.tscn"

var out_dir := "user://detail_clock_tower_shots"
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not args[0].begins_with("--"):
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(1800.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var args := OS.get_cmdline_user_args()
	var game := root.get_node("Game")
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Settings").tips = false
	root.get_node("Settings").minimap = false
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.set_time(3, 11 * 60.0, true)
	var detail := root.get_node("WorldDetail")
	if "--old-props" in args:
		detail.detail_props = false
		detail.batching = false
		detail.lods = false
		detail.plant_shadows = true
	change_scene_to_file(WORLD)
	for i in 16:
		await process_frame
	await create_timer(3.5).timeout
	var lw := current_scene.get_node_or_null("Mesh LODs")
	while lw and lw.busy():
		await process_frame
	var s := current_scene
	s.set_process(false)
	s.set_physics_process(false)
	var player := s.find_child("Player", true, false) as Node3D
	if player:
		player.global_position = Vector3(0, 0.5, 2)             # out of the shots
		player.visible = false
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	cam = Camera3D.new()
	cam.fov = 55
	cam.far = 3000
	s.add_child(cam)
	cam.make_current()
	var views := []
	views.append(["01_walk", Vector3(0, 3.2, 2), Vector3(0, 5, 30)])
	views.append(["02_gear_wall", Vector3(-4, 4, 10), Vector3(-12, 5, 16)])
	views.append(["03_pendulum", Vector3(4, 7, 18), Vector3(0, 6, 22)])
	views.append(["04_frame_top", Vector3(-3, 10, 26), Vector3(-9, 11.5, 30)])
	views.append(["05_cog_gate", Vector3(0, 5, 34), Vector3(0, 6, 46)])
	views.append(["06_door_from_walk", Vector3(4, 4, 30), Vector3(0, 6, 43)])
	views.append(["07_arena_wide", Vector3(0, 9, 48), Vector3(0, 6, 88)])
	views.append(["08_big_clock", Vector3(0, 9, 76), Vector3(0, 10, 92.6)])
	views.append(["09_wall_bay", Vector3(-6, 4, 66), Vector3(-24, 9, 76)])
	views.append(["10_dais_cuckoo", Vector3(-8, 3, 72), Vector3(-3, 1, 80)])
	views.append(["11_rail", Vector3(10, 2, 60), Vector3(17, 0.6, 66)])
	views.append(["12_overhead", Vector3(45, 45, 20), Vector3(0, 0, 55)])
	for v in views:
		cam.global_position = v[1]
		cam.look_at(v[2])
		await _shot(v[0])
	_finish()


func _shot(file: String) -> void:
	for i in 12:
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
	quit(0)

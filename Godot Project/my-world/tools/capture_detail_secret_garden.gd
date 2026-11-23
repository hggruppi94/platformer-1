extends SceneTree

# Pictures for the Secret Garden's baked props: its ivy-covered walls, the Rose Walk's arches, the fountain, the maze's
# hedges and sundial, the summerhouse, the Giant Flowers, the Great Tree and the benches (23 Nov 2026,
# tools/build_prop_secret_garden.py, scripts/detail_props.gd dress_secret_garden()). With --old-props it shoots the same spots with
# everything the pipeline adds turned off, so the two sets make a before and after.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_detail_secret_garden.gd -- <folder> [--old-props]
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.detail_secret_garden_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.detail_secret_garden_capture_backup.cfg"
const WORLD := "res://scenes/secret_garden/secret_garden.tscn"

var out_dir := "user://detail_secret_garden_shots"
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
		player.global_position = Vector3(0, 0.5, 140)            # out of the shots
		player.visible = false
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	cam = Camera3D.new()
	cam.fov = 55
	cam.far = 3000
	s.add_child(cam)
	cam.make_current()
	var views := []
	views.append(["01_rose_walk", Vector3(0, 2.2, 3), Vector3(0, 2, 22)])
	views.append(["02_arch_close", Vector3(3.5, 2, 9), Vector3(0, 2.6, 12.4)])
	views.append(["03_wall_ivy", Vector3(-50, 2.5, 20), Vector3(-70, 2.5, 30)])
	views.append(["04_fountain", Vector3(8, 3.5, 40), Vector3(0, 1.5, 52)])
	views.append(["05_bench", Vector3(5, 2, 62), Vector3(0, 0.5, 67)])
	views.append(["06_maze", Vector3(-26, 9, 34), Vector3(-42, 0, 52)])
	views.append(["07_sundial", Vector3(-38.5, 2.2, 49), Vector3(-41.1, 0.8, 52.9)])
	views.append(["08_summerhouse", Vector3(28, 4, 46), Vector3(40, 2, 54)])
	views.append(["09_flowers", Vector3(0, 7, 88), Vector3(0, 4, 108)])
	views.append(["10_flower_close", Vector3(6, 6, 100), Vector3(0, 4, 104)])
	views.append(["11_great_tree", Vector3(-30, 6, 104), Vector3(-44, 7, 118)])
	views.append(["12_wide", Vector3(40, 40, -10), Vector3(0, 0, 70)])
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

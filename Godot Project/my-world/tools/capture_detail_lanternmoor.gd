extends SceneTree

# Pictures for Lanternmoor's baked props: its lantern trees, the Night Path's lantern posts, the three beacons and
# the standing stones (20 Nov 2026, tools/build_prop_lanternmoor.py, scripts/detail_props.gd dress_lanternmoor()). With --old-props it shoots the same spots
# with everything the pipeline adds turned off, so the two sets make a before and after.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_detail_lanternmoor.gd -- <folder> [--old-props]
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.detail_lanternmoor_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.detail_lanternmoor_capture_backup.cfg"
const LANTERNMOOR := "res://scenes/portal_worlds/lanternmoor.tscn"

var out_dir := "user://detail_lanternmoor_shots"
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
	change_scene_to_file(LANTERNMOOR)
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
		player.global_position = Vector3(-60, 2, 60)            # out of the shots
		player.visible = false
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	cam = Camera3D.new()
	cam.fov = 55
	cam.far = 3000
	s.add_child(cam)
	cam.make_current()
	var views := []
	views.append(["01_beacon_stones", Vector3(-27, 3.2, -1), Vector3(-33, 2.2, -7)])
	views.append(["02_beacon_close", Vector3(-30.2, 3.6, -4.6), Vector3(-33, 3.2, -7)])
	views.append(["03_night_path", Vector3(-2, 2.4, 23), Vector3(-21, 1.2, 12)])
	views.append(["04_path_lantern", Vector3(-11.5, 2.2, 19.5), Vector3(-14, 1.6, 17)])
	views.append(["05_lantern_grove", Vector3(-16, 5, -10), Vector3(-16, 2, -26)])
	views.append(["06_grove_tree", Vector3(-6, 3.0, -21), Vector3(-5.5, 2.6, -26)])
	views.append(["07_tall_tree", Vector3(22, 6, 8), Vector3(10, 5, -4)])
	views.append(["08_moor_wide", Vector3(0, 16, 40), Vector3(0, 2, -5)])
	views.append(["09_sunrise_hill", Vector3(14, 5, -24), Vector3(4, 2, -38)])
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

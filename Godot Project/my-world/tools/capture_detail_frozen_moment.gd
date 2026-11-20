extends SceneTree

# Pictures for the Frozen Moment's baked props: its snowy pines, the ice crags round the edge and the Frost Throne
# (20 Nov 2026, tools/build_prop_frozen_moment.py, scripts/detail_props.gd dress_frozen_moment()). With --old-props it shoots the same spots
# with everything the pipeline adds turned off, so the two sets make a before and after.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_detail_frozen_moment.gd -- <folder> [--old-props]
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.detail_frozen_moment_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.detail_frozen_moment_capture_backup.cfg"
const FROZEN := "res://scenes/portal_worlds/frozen_moment.tscn"

var out_dir := "user://detail_frozen_moment_shots"
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
	change_scene_to_file(FROZEN)
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
		player.global_position = Vector3(0, 2, 38)              # out of the shots
		player.visible = false
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	cam = Camera3D.new()
	cam.fov = 55
	cam.far = 3000
	s.add_child(cam)
	cam.make_current()
	# The pines and crags stand where the builder's dice put them, so the shots look for them
	var pine := Vector3(30, 0, 0)
	for c in s.find_child("Pines", true, false).get_children():
		if c is MeshInstance3D and c.material_override and c.material_override.resource_name == "Pine Bark":
			pine = Vector3(c.position.x, 0, c.position.z)
			break
	var pin := -pine.normalized()
	var views := []
	views.append(["01_throne", Vector3(0, 4.5, -11), Vector3(0, 1.0, -24)])
	views.append(["02_throne_close", Vector3(3.5, 2.2, -17.5), Vector3(3.2, 1.0, -21.5)])
	views.append(["03_pine", pine + pin * 9.0 + Vector3(0, 3.0, 0), pine + Vector3(0, 3.0, 0)])
	views.append(["04_pine_close", pine + pin * 4.0 + Vector3(0, 3.4, 0), pine + Vector3(0, 3.2, 0)])
	views.append(["05_crags", pine + pin * 14.0 + Vector3(0, 4.0, 0), pine * 1.15 + Vector3(0, 8.0, 0)])
	views.append(["06_lake_wide", Vector3(0, 9, 26), Vector3(0, 3, -20)])
	views.append(["07_bowl_high", Vector3(-20, 22, 30), Vector3(5, 0, -10)])
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

extends SceneTree

# Pictures of the Hot Springs' caves (front, both sides, inside) to check nothing clips. Old header:, Pip's lantern posts, the Mothership Pad, the noticeboard and the Hot Springs'
# caves (19 Nov 2026, tools/build_prop_void_5.py, scripts/detail_props.gd). With --old-props it shoots the same spots
# with everything the pipeline adds turned off, so the two sets make a before and after.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_hot_springs.gd -- <folder> [--old-props]
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.hot_springs_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.hot_springs_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://hot_springs_shots"
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
	change_scene_to_file(TOWN)
	for i in 16:
		await process_frame
	await create_timer(3.5).timeout
	var lw := current_scene.get_node_or_null("Mesh LODs")
	while lw and lw.busy():
		await process_frame
	var player := current_scene.find_child("Player", true, false) as Node3D
	if player:
		player.global_position = Vector3(40, 2, 120)            # out of the shots
		player.visible = false
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	cam = Camera3D.new()
	cam.fov = 55
	cam.far = 3000
	current_scene.add_child(cam)
	cam.make_current()
	var s := current_scene
	var views := []
	var caves := []
	for c in s.get_node("Hot Springs").get_children():
		var mi := c as MeshInstance3D
		if mi and mi.material_override and mi.material_override.resource_name == "Cave Rock":
			caves.append([mi.global_position - Vector3(0, 1, 0), float(mi.get_meta("spring_yaw", 0.0))])
	var mid: Vector3 = caves[1][0]
	views.append(["00_all_caves", mid + Vector3(4, 7, 22), mid + Vector3(0, 2, 0), 11.0])
	for i in caves.size():
		var p: Vector3 = caves[i][0]
		var f := Vector3(sin(caves[i][1]), 0, cos(caves[i][1]))
		var sd := Vector3(f.z, 0, -f.x)
		views.append(["%d_front" % (i + 1), p + f * 7 + Vector3(0, 1.8, 0), p + Vector3(0, 1.2, 0), 11.0])
		views.append(["%d_left" % (i + 1), p + f * 3.5 - sd * 5 + Vector3(0, 1.8, 0), p + Vector3(0, 1.2, 0), 11.0])
		views.append(["%d_right" % (i + 1), p + f * 3.5 + sd * 5 + Vector3(0, 1.8, 0), p + Vector3(0, 1.2, 0), 11.0])
		views.append(["%d_inside" % (i + 1), p + f * 2.2 + Vector3(0, 1.3, 0), p - f + Vector3(0, 0.9, 0), 11.0])
	for v in views:
		clock.set_time(3, v[3] * 60.0, true)
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

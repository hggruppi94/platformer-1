extends SceneTree

# Pictures for the Dark Hollow's baked props: its crooked trees, the Hollow Log, the glowing mushrooms, the
# lamp posts and the old stones (20 Nov 2026, tools/build_prop_dark_hollow.py, scripts/detail_props.gd dress_dark_hollow()). With --old-props it shoots the same spots
# with everything the pipeline adds turned off, so the two sets make a before and after.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_detail_dark_hollow.gd -- <folder> [--old-props]
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.detail_dark_hollow_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.detail_dark_hollow_capture_backup.cfg"
const DARK_HOLLOW := "res://scenes/portal_worlds/dark_hollow.tscn"

var out_dir := "user://detail_dark_hollow_shots"
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
	change_scene_to_file(DARK_HOLLOW)
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
	var lg := s.get_node("Hollow Log") as Node3D
	var lx := lg.global_basis.x.normalized()
	var lz := lg.global_basis.z.normalized()
	var lp := lg.global_position
	views.append(["01_hollow_log", lp + lx * 6.5 + lz * 4.5 + Vector3(0, 2.6, 0), lp + lx * 1.0 + Vector3(0, 1.2, 0)])
	views.append(["02_log_side", lp - lz * 7.5 + Vector3(0, 2.4, 0), lp + Vector3(0, 1.2, 0)])
	views.append(["03_ghost_glade", Vector3(-26, 4.5, 9), Vector3(-26, 1.2, -4)])
	views.append(["04_hush_hill", Vector3(0, 6, -8), Vector3(0, 1.5, -28)])
	var mlp := Vector3(9.5, 0, -28)
	views.append(["05_moon_lamp", mlp + Vector3(2.4, 2.4, 2.6), mlp + Vector3(0, 1.9, 0)])
	var cap: Node3D
	for c in s.get_node("Glow Mushrooms").get_children():
		if c is MeshInstance3D and String((c as MeshInstance3D).get_active_material(0).resource_name).begins_with("Mushroom 0"):
			cap = c
			break
	var cp := cap.global_position
	views.append(["06_mushrooms", cp + Vector3(1.6, 1.0, 1.6), Vector3(cp.x, 0.3, cp.z)])
	var flame: Node3D
	for c in s.get_node("Run Lamps").get_children():
		if c is MeshInstance3D and String((c as MeshInstance3D).get_active_material(0).resource_name) == "Lamp Flame":
			flame = c
			break
	var fp := flame.global_position
	views.append(["07_run_lamp", fp + Vector3(2.4, -0.6, 2.4), fp - Vector3(0, 1.0, 0)])
	views.append(["08_hollow_wide", Vector3(0, 18, 52), Vector3(0, 2, 0)])
	views.append(["09_banks", Vector3(-30, 6, 30), Vector3(-45, 6, 40)])
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

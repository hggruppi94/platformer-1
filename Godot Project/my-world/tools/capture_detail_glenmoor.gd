extends SceneTree

# Pictures for Glenmoor's baked props: the Standing Stones, the cairns up Ben Bonnie, Heather's croft and her barn with
# its hay bales (19 Nov 2026, tools/build_prop_glenmoor.py, scripts/detail_props.gd dress_glenmoor()). With --old-props it shoots the same spots
# with everything the pipeline adds turned off, so the two sets make a before and after.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_detail_glenmoor.gd -- <folder> [--old-props]
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.detail_glenmoor_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.detail_glenmoor_capture_backup.cfg"
const GLENMOOR := "res://scenes/portal_worlds/glenmoor.tscn"

var out_dir := "user://detail_glenmoor_shots"
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
	change_scene_to_file(GLENMOOR)
	for i in 16:
		await process_frame
	await create_timer(3.5).timeout
	var lw := current_scene.get_node_or_null("Mesh LODs")
	while lw and lw.busy():
		await process_frame
	var s := current_scene
	# Hold the glen's day still (it loops between day and night by itself)
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
	var ring := s.find_child("Standing Stones", true, false) as Node3D
	var rc := ring.global_position
	views.append(["01_standing_stones", rc + Vector3(13, 4.5, 14), rc + Vector3(0, 1.5, 0), 0.04])
	var first := ring.get_node("Stone") as Node3D
	var fp := first.global_position
	var out := Vector3(fp.x - rc.x, 0, fp.z - rc.z).normalized()
	views.append(["02_stone_close", fp + out * 3.2 + Vector3(0, 0.6, 0) + out.cross(Vector3.UP) * 1.2, fp + Vector3(0, 0.4, 0), 0.04])
	var croft := s.find_child("Heather's Croft", true, false) as Node3D
	var cf := -croft.global_basis.z.normalized()
	var cx := croft.global_basis.x.normalized()
	var cp := croft.global_position
	views.append(["03_croft", cp + cf * 15 - cx * 7 + Vector3(0, 4, 0), cp + Vector3(0, 2.5, 0), 0.04])
	views.append(["04_croft_porch", cp + cf * 7.5 - cx * 2.5 + Vector3(0, 1.7, 0), cp + cf * 4 + Vector3(0, 1.4, 0), 0.04])
	var barn := s.find_child("Barn", true, false) as Node3D
	var bp := barn.global_position
	var bx := barn.global_basis.x.normalized()
	var bz := barn.global_basis.z.normalized()
	views.append(["05_barn", bp - bx * 14 + bz * 9 + Vector3(0, 4, 0), bp + Vector3(0, 3.5, 0), 0.04])
	views.append(["06_barn_doors_hay", bp - bx * 8 - bz * 4 + Vector3(0, 1.8, 0), bp - bx * 4 + Vector3(0, 1.2, 0), 0.04])
	var cairns := []
	for f in s.find_children("Flag", "MeshInstance3D", true, false):
		cairns.append((f as Node3D).get_parent())
	cairns.sort_custom(func(a, b): return a.global_position.y < b.global_position.y)
	if cairns.size() > 0:
		var c0 := cairns[0] as Node3D
		views.append(["07_cairn", c0.global_position + Vector3(3.2, 1.8, 3.2), c0.global_position + Vector3(0.3, 1.2, 0), 0.04])
		var top := cairns[cairns.size() - 1] as Node3D
		views.append(["08_summit_cairn", top.global_position + Vector3(4.5, 2.4, 4.5), top.global_position + Vector3(0.3, 1.4, 0), 0.04])
	views.append(["09_croft_dusk", cp + cf * 15 - cx * 7 + Vector3(0, 4, 0), cp + Vector3(0, 2.5, 0), 0.3])
	views.append(["10_stones_night", rc + Vector3(13, 4.5, 14), rc + Vector3(0, 1.5, 0), 0.5])
	for v in views:
		if s.has_method("set_daylight"):
			s.set_daylight(v[3])
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

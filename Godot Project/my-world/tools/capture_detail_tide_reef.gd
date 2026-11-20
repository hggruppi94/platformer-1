extends SceneTree

# Pictures for the Tide Reef's baked props: its coral houses, bubble lamps and the stranded boat (20 Nov 2026,
# tools/build_prop_tide_reef.py, scripts/detail_props.gd dress_tide_reef()). With --old-props it shoots the same spots
# with everything the pipeline adds turned off, so the two sets make a before and after.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_detail_tide_reef.gd -- <folder> [--old-props]
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.detail_tide_reef_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.detail_tide_reef_capture_backup.cfg"
const TIDE_REEF := "res://scenes/portal_worlds/tide_reef.tscn"

var out_dir := "user://detail_tide_reef_shots"
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
	change_scene_to_file(TIDE_REEF)
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
	var h1 := s.get_node("Coral House 1") as Node3D
	var f1 := h1.global_basis.z.normalized()
	var x1 := h1.global_basis.x.normalized()
	var p1 := h1.global_position
	views.append(["01_coral_house", p1 + f1 * 9 + x1 * 3 + Vector3(0, 3, 0), p1 + Vector3(0, 1.8, 0), 0.0])
	views.append(["02_house_door", p1 + f1 * 5.2 + x1 * 1.2 + Vector3(0, 1.4, 0), p1 + f1 * 2.4 + Vector3(0, 1.1, 0), 0.0])
	views.append(["03_houses", Vector3(0, 9, 34), Vector3(0, 1, 6), 0.0])
	var lamps := s.get_node("Bubble Lamps") as Node3D
	var lp: Vector3 = (lamps.get_child(0) as Node3D).global_position
	views.append(["04_bubble_lamp", lp + Vector3(2.2, 0.5, 2.2), lp + Vector3(0, 0.3, 0), 0.0])
	var boat := s.get_node("Stranded Boat") as Node3D
	var bp := boat.global_position
	views.append(["05_boat", bp + Vector3(5, 3, 5), bp + Vector3(0, 1.2, 0), 0.0])
	views.append(["06_coral_house_tide_in", p1 + f1 * 9 + x1 * 3 + Vector3(0, 3, 0), p1 + Vector3(0, 1.8, 0), 1.0])
	views.append(["07_houses_tide_in", Vector3(0, 9, 34), Vector3(0, 1, 6), 1.0])
	for v in views:
		if s.has_method("set_tide"):
			s.set_tide(v[3])
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

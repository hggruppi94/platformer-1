extends SceneTree

# Pictures for the Skyreach Trail's baked props: the kerb stones, the Waystones, the pines, the cliff crystals, the
# prayer flags, the summit's ring of rocks, the Star Blooms and the Star Chest (24 Nov 2026,
# tools/build_prop_skyreach.py, scripts/detail_props.gd dress_skyreach()). With --old-props it shoots the same
# spots with everything the pipeline adds turned off, so the two sets make a before and after.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_detail_skyreach.gd -- <folder> [--old-props]
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.detail_skyreach_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.detail_skyreach_capture_backup.cfg"
const WORLD := "res://scenes/bosses/skyreach_trail.tscn"

var out_dir := "user://detail_skyreach_shots"
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
		player.global_position = Vector3(0, 0.5, -4)             # out of the shots
		player.visible = false
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	cam = Camera3D.new()
	cam.fov = 55
	cam.far = 3000
	s.add_child(cam)
	cam.make_current()
	var views := []
	var top: Vector3 = s.call("summit")
	var p0: Vector3 = s.call("trail_point", 0.25)
	var p1: Vector3 = s.call("trail_point", 0.45)
	views.append(["01_trail_start", p0 + Vector3(0, 2.2, 0) - (p1 - p0).normalized() * 4.0, p1 + Vector3(0, 1.2, 0)])
	var w := (s.get_node("Waystone 2") as Node3D).global_position
	views.append(["02_waystone", w + Vector3(2.2, 1.8, 2.2), w + Vector3(0, 1.2, 0)])
	var pine := Vector3(0, 0, 90) + Vector3(sin(1.2) * 70.0, 0, -cos(1.2) * 70.0)
	views.append(["03_pines", pine + Vector3(0, 4, 0), Vector3(0, 6, 90) + Vector3(sin(1.2) * 80.0, 0, -cos(1.2) * 80.0)])
	var f: Vector3 = s.call("trail_point", 3.0 * PI * 3.5 / 9.0)
	var f2: Vector3 = s.call("trail_point", 3.0 * PI * 3.5 / 9.0 + 0.2)
	views.append(["04_flags", f + Vector3(0, 2.0, 0) + (f - f2).normalized() * 3.0, f + Vector3(0, 3.0, 0)])
	var cr := s.find_child("Cliff Crystal", true, false) as Node3D
	if cr:
		var cp := cr.global_position
		views.append(["05_crystals", cp + (Vector3(0, 0, 90) - cp).normalized() * -3.5 + Vector3(0, 1.2, 0), cp])
	views.append(["06_summit", top + Vector3(0, 5, 24), top + Vector3(0, 0, -4)])
	views.append(["07_ring_rocks", top + Vector3(-12, 2.5, 12), top + Vector3(-19, 0.5, 19)])
	var ch := (s.get_node("Star Chest") as Node3D).global_position
	views.append(["08_chest", ch + Vector3(2.5, 1.8, 3.0), ch + Vector3(0, 0.6, 0)])
	views.append(["09_blooms", top + Vector3(4, 1.4, 10), top + Vector3(0, 0.2, 6.8)])
	views.append(["10_whole", Vector3(110, 70, 10), Vector3(0, 18, 90)])
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

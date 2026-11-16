extends SceneTree

# Pictures for the fifth batch of baked props (16 Nov 2026): the playground by Willow Pond (the slide tower, the swings
# and the sandbox) and the stone planters of mums down Main Street.
# With --old-props the same spots with the whole pipeline turned off, for a before and after.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_detail_play.gd -- <folder> [--old-props]
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.detail_play_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.detail_play_capture_backup.cfg"
const EARTH := "res://scenes/earth/earth.tscn"

var out_dir := "user://detail_play_shots"
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
	var detail := root.get_node("WorldDetail")
	if "--old-props" in args:
		detail.detail_props = false
		detail.batching = false
		detail.lods = false
		detail.plant_shadows = true
	clock.set_earth_time(11 * 60.0, true)
	await _load(EARTH)
	var play := current_scene.find_child("Playground", true, false) as Node3D
	if play:
		await _view("01_playground", play, Vector3(2.0, 5.5, 12.0), Vector3(0, 1.0, 0))
		await _view("02_slide", play, Vector3(2.5, 2.6, 5.5), Vector3(-3.0, 1.6, 0.5))
		await _view("03_slide_back", play, Vector3(-6.5, 2.8, -5.0), Vector3(-3.0, 1.8, -0.5))
		await _view("04_swings", play, Vector3(4.5, 1.8, 3.2), Vector3(3.5, 1.3, -2.0))
		await _view("05_sandbox", play, Vector3(4.6, 2.2, 7.0), Vector3(2.5, 0.2, 4.0))
	var planter := _first_box("Planter Stone")
	if planter:
		var at := _spot(planter.global_position * Vector3(1, 0, 1) + Vector3(0, planter.global_position.y - 0.28, 0))
		await _view("06_planter", at, Vector3(2.2, 1.6, 2.4), Vector3(0, 0.5, 0))
		await _view("07_main_street", at, Vector3(4.0, 2.6, 9.0), Vector3(0, 0.6, -2.0))
	clock.set_earth_time(19 * 60.0 + 40, true)
	await create_timer(0.5).timeout
	if play:
		await _view("08_playground_dusk", play, Vector3(2.0, 5.5, 12.0), Vector3(0, 1.0, 0))
	_finish()


func _first_box(mat_name: String) -> MeshInstance3D:
	# The builder's piece of this material nearest the middle of town, with or without the swap
	var best: MeshInstance3D = null
	for n in current_scene.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh is BoxMesh and mi.material_override and String(mi.material_override.resource_name) == mat_name:
			if best == null or mi.global_position.length() < best.global_position.length():
				best = mi
	return best


func _spot(at: Vector3) -> Node3D:
	var s := Node3D.new()
	current_scene.add_child(s)
	s.global_position = at
	return s


func _load(path: String) -> void:
	change_scene_to_file(path)
	for i in 16:
		await process_frame
	await create_timer(3.5).timeout
	var lw := current_scene.get_node_or_null("Mesh LODs")
	while lw and lw.busy():
		await process_frame
	var player := current_scene.find_child("Player", true, false) as Node3D
	if player:
		player.global_position += Vector3(0, -200, 0)            # out of the shots
		player.visible = false
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	cam = Camera3D.new()
	cam.fov = 55
	cam.far = 3000
	current_scene.add_child(cam)
	cam.make_current()


func _view(file: String, at: Node3D, from: Vector3, look: Vector3) -> void:
	cam.global_position = at.global_transform * from
	cam.look_at(at.global_transform * look)
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	for pair in [[BACKUP, SAVE], [SETTINGS_BACKUP, SETTINGS]]:
		if FileAccess.file_exists(pair[0]):
			DirAccess.copy_absolute(pair[0], pair[1])
			DirAccess.remove_absolute(pair[0])
		else:
			DirAccess.remove_absolute(pair[1])
	quit()

extends SceneTree

# Pictures for the sixth batch of baked props (16 Nov 2026): the old covered bridge on Maple Lane, the footbridge over
# Whisper Creek, Willow Pond's dock and the coin telescope on Lookout Hill.
# With --old-props the same spots with the whole pipeline turned off, for a before and after.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_detail_creek.gd -- <folder> [--old-props]
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.detail_creek_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.detail_creek_capture_backup.cfg"
const EARTH := "res://scenes/earth/earth.tscn"

var out_dir := "user://detail_creek_shots"
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
	var cb := current_scene.find_child("Covered Bridge", true, false) as Node3D
	if cb:
		await _view("01_covered_bridge", cb, Vector3(-4.0, 3.0, -16.0), Vector3(0, 2.4, 0))
		await _view("02_bridge_end", cb, Vector3(15.0, 2.2, 5.0), Vector3(0, 2.6, 0))
		await _view("03_bridge_inside", cb, Vector3(-5.5, 1.7, 1.2), Vector3(5.0, 2.6, -0.5))
	var fb := _deck("Footbridge", "Bridge Wood")
	if fb:
		await _view("04_footbridge", fb, Vector3(5.0, 2.4, 3.0), Vector3(0, 0.2, 0))
		await _view("05_footbridge_low", fb, Vector3(-3.5, 0.6, 1.0), Vector3(0, 0.0, 0))
	var dk := _deck("Dock", "Bridge Wood")
	if dk:
		await _view("06_dock", dk, Vector3(3.0, 2.6, 7.0), Vector3(-2.0, 0.2, 0))
		await _view("07_dock_end", dk, Vector3(-9.5, 1.4, 3.0), Vector3(-6.0, 0.3, 0))
	var top := current_scene.find_child("Lookout", true, false) as Node3D
	if top:
		await _view("08_telescope", top, Vector3(3.0, 1.6, 2.8), Vector3(2.0, 1.1, 0.6))
		await _view("09_telescope_back", top, Vector3(4.2, 1.7, 0.2), Vector3(2.0, 1.0, 0.6))
	clock.set_earth_time(19 * 60.0 + 40, true)
	await create_timer(0.5).timeout
	if cb:
		await _view("10_bridge_dusk", cb, Vector3(15.0, 2.2, 5.0), Vector3(0, 2.6, 0))
	_finish()


func _deck(node_name: String, mat_name: String) -> Node3D:
	# A spot on the ground under the builder's deck of this node, turned the way the deck runs
	var g := current_scene.find_child(node_name, true, false) as Node3D
	if g == null:
		return null
	for c in g.get_children():
		var mi := c as MeshInstance3D
		if mi and mi.material_override and String(mi.material_override.resource_name) == mat_name:
			var s := _spot(mi.global_position * Vector3(1, 0, 1))
			s.rotation.y = mi.global_rotation.y
			return s
	return null


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

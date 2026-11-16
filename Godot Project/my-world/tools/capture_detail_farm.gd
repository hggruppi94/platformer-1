extends SceneTree

# Pictures for the fourth batch of baked props (16 Nov 2026): Stars Hollow's round hay bales, the cornstalk sheaves on
# the green's lamps, the fire engine outside Fire Station No. 1 and the rowing boat at Willow Pond's dock.
# With --old-props the same spots with the whole pipeline turned off, for a before and after.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_detail_farm.gd -- <folder> [--old-props]
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.detail_farm_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.detail_farm_capture_backup.cfg"
const EARTH := "res://scenes/earth/earth.tscn"

var out_dir := "user://detail_farm_shots"
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
	var truck := current_scene.find_child("Fire Truck", true, false) as Node3D
	if truck:
		await _view("01_fire_truck", truck, Vector3(5.5, 2.4, 7.5), Vector3(0, 1.3, 0.5))
		await _view("02_fire_truck_front", truck, Vector3(-1.6, 1.5, 5.6), Vector3(0, 1.3, 2.0))
		await _view("03_fire_truck_side", truck, Vector3(-6.5, 2.6, 2.0), Vector3(0, 1.3, 0.0))
	var boat := current_scene.find_child("Rowing Boat", true, false) as Node3D
	if boat:
		await _view("04_boat", _spot(boat.global_position), Vector3(3.5, 2.2, 3.5), Vector3(0, 0.1, 0))
		await _view("05_boat_close", _spot(boat.global_position), Vector3(1.6, 1.6, -1.2), Vector3(0, 0.0, 0.3))
	var hay := _first("Hay", 1.2)
	if hay:
		await _view("06_hay", _spot(hay.global_position), Vector3(1.8, 1.0, 2.6), Vector3(0, 0.1, 0))
	var corn := _first("Cornstalk", 2.2)
	if corn:
		var at := _spot(corn.global_position - Vector3(0, 1.1, 0))
		await _view("07_corn", at, Vector3(1.6, 1.6, 2.4), Vector3(0, 1.1, 0))
		await _view("08_corn_lamps", at, Vector3(6.0, 3.0, 8.0), Vector3(0, 1.0, 0))
	clock.set_earth_time(19 * 60.0 + 40, true)
	await create_timer(0.5).timeout
	if truck:
		await _view("09_fire_truck_dusk", truck, Vector3(5.5, 2.4, 7.5), Vector3(0, 1.3, 0.5))
	_finish()


func _first(mat_name: String, size: float) -> MeshInstance3D:
	# The first builder piece of this kind (found by its material and size, as the swap finds it), with or without it
	var best: MeshInstance3D = null
	for n in current_scene.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh is CylinderMesh and mi.material_override and String(mi.material_override.resource_name) == mat_name \
				and is_equal_approx((mi.mesh as CylinderMesh).height, size):
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

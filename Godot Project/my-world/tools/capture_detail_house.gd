extends SceneTree

# Pictures for the third batch of baked props (16 Nov 2026): Maple Lane's picket fences and porches (by day, at dusk
# and in winter, when the porch roofs keep their snow), and the Void's fountains and lamp posts (by day and at night).
# With --old-props the same spots with the whole pipeline turned off, for a before and after.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_detail_house.gd -- <folder> [--old-props]
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.detail_house_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.detail_house_capture_backup.cfg"
const EARTH := "res://scenes/earth/earth.tscn"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://detail_house_shots"
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
	# Stars Hollow, in autumn (a new game's season)
	clock.set_earth_time(11 * 60.0, true)
	await _load(EARTH)
	var house := current_scene.find_child("Maple House 1", true, false) as Node3D
	if house:
		await _view("01_house_front", house, Vector3(4.5, 2.2, 15.0), Vector3(0, 1.6, 3.5))
		await _view("02_porch_close", house, Vector3(2.6, 1.6, 7.5), Vector3(-0.6, 1.4, 3.0))
		await _view("03_fence_close", house, Vector3(-3.5, 1.0, 9.8), Vector3(-0.5, 0.6, 7.5))
		await _view("04_lane", house, Vector3(-14, 4.0, 13.0), Vector3(6, 1.2, 3.0))
		clock.set_earth_time(19 * 60.0 + 30, true)
		await create_timer(0.5).timeout
		await _view("05_porch_dusk", house, Vector3(4.5, 2.2, 15.0), Vector3(0, 1.6, 3.5))
	# Winter: the porch roofs take the snow like the house roofs
	clock.on_earth = true
	clock.set_time(clock.day_of("winter", 3, 1), 13 * 60.0, true)
	clock.earth_minutes = 13 * 60.0
	await _load(EARTH)
	house = current_scene.find_child("Maple House 1", true, false) as Node3D
	if house:
		await _view("06_porch_winter", house, Vector3(4.5, 3.0, 15.0), Vector3(0, 1.8, 3.5))
	# The Void
	clock.on_earth = false
	clock.set_time(3, 11 * 60.0, true)
	await _load(TOWN)
	var market := current_scene.get_node_or_null("Market Square") as Node3D
	if market:
		await _view("07_fountain", market, Vector3(6.5, 4.0, 7.0), Vector3(0, 1.4, 0))
		await _view("08_fountain_close", market, Vector3(3.2, 2.0, 3.0), Vector3(0, 1.6, 0))
	var lamp := _lamp("Market Square")
	if lamp:
		await _view("09_lamp", lamp, Vector3(2.2, 2.4, 3.2), Vector3(0, 2.4, 0))
	var castle_lamp := _lamp("Castle Grounds")
	clock.set_time(3, 22 * 60.0, true)
	await create_timer(1.0).timeout
	if lamp:
		await _view("10_lamp_night", lamp, Vector3(2.2, 2.4, 3.2), Vector3(0, 2.4, 0))
	if market:
		await _view("11_fountain_night", market, Vector3(6.5, 4.0, 7.0), Vector3(0, 1.4, 0))
	if castle_lamp:
		await _view("12_castle_lamps_night", castle_lamp, Vector3(3.0, 2.5, 6.0), Vector3(0, 2.0, -4.0))
	_finish()


func _lamp(group: String) -> Node3D:
	# A lamp post's pole, by the same names the swap looks for, so the shot's on the same spot with or without it.
	for n in current_scene.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh is CylinderMesh and mi.material_override and String(mi.material_override.resource_name).ends_with("Post") \
				and String(mi.get_parent().name).begins_with(group):
			var spot := Node3D.new()
			mi.get_parent().add_child(spot)
			spot.global_position = mi.global_position - Vector3(0, (mi.mesh as CylinderMesh).height / 2.0, 0)
			return spot
	return null


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

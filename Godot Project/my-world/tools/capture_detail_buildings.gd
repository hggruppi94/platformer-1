extends SceneTree

# Pictures for the baked building outsides (19 Nov 2026, tools/build_prop_surfaces.py, scripts/detail_props.gd
# dress_buildings): Stars Hollow's siding, shingles, brick, stone and the barn's boards, and the Void's dome scales.
# With --old-props it shoots the same spots with everything the pipeline adds turned off, so the two sets make a
# before and after.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_detail_buildings.gd -- <folder> [--old-props]
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.detail_buildings_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.detail_buildings_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"

var out_dir := "user://detail_buildings_shots"
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

	# Stars Hollow at noon: each building from its street side, a little off square so the siding's laps show
	clock.on_earth = true
	clock.set_earth_time(12 * 60.0, true)
	await _open(EARTH)
	var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://ui/earth_map.json"))
	var views := []
	var n := 1
	for b in map["buildings"]:
		var name: String = b[0]
		if not name in ["Hollow Diner", "Maple Inn", "Fire Station No. 1", "Lantern Hill Library", "Old Oak Elementary",
				"Palmer House", "Maple House 2", "Dance Studio"]:
			continue
		var at := Vector3(b[1], 0, b[2])
		var size := maxf(b[3], b[4])
		var front := Vector3(sin(b[5]), 0, cos(b[5]))
		var side := front.cross(Vector3.UP)
		views.append(["%02d_%s" % [n, name.to_snake_case().replace("&", "and").replace(".", "")],
			at + front * (size * 1.3 + 4.0) + side * size * 0.45 + Vector3(0, 3.2, 0), at + Vector3(0, 3.0, 0)])
		views.append(["%02d_%s_close" % [n + 1, name.to_snake_case().replace("&", "and").replace(".", "")],
			at + front * (size * 0.5 + 3.5) + side * size * 0.2 + Vector3(0, 2.4, 0), at + front * size * 0.5 + Vector3(0, 3.4, 0)])
		n += 2
	await _shoot(views)

	# The Void's domes, from the ground and close up under the scales
	clock.on_earth = false
	clock.set_time(3, 11 * 60.0, true)
	await _open(TOWN)
	views = []
	var domes := []
	for mi in current_scene.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		if m is SphereMesh and (m as SphereMesh).radius > 4.0:
			var mat := (mi as MeshInstance3D).material_override
			if mat == null:
				mat = m.surface_get_material(0)
			if mat and String(mat.resource_name).begins_with("Dome ("):
				domes.append(mi)
	domes.sort_custom(func(a, b): return a.mesh.radius > b.mesh.radius)
	for i in mini(3, domes.size()):
		var d: MeshInstance3D = domes[i]
		var c := d.global_position
		var r: float = d.mesh.radius * d.global_basis.get_scale().x
		views.append(["%02d_void_dome_%d" % [n, i + 1], c + Vector3(r * 1.6, r * 0.6 + 2.0, r * 1.6), c + Vector3(0, r * 0.3, 0)])
		views.append(["%02d_void_dome_%d_close" % [n + 1, i + 1], c + Vector3(r * 0.95, r * 0.75, r * 0.95), c + Vector3(0, r * 0.55, 0)])
		n += 2
	await _shoot(views)
	_finish()


func _open(path: String) -> void:
	change_scene_to_file(path)
	for i in 16:
		await process_frame
	await create_timer(3.5).timeout
	var lw := current_scene.get_node_or_null("Mesh LODs")
	while lw and lw.busy():
		await process_frame
	var player := current_scene.find_child("Player", true, false) as Node3D
	if player:
		player.global_position = Vector3(40, 2, 160)            # out of the shots
		player.visible = false
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	cam = Camera3D.new()
	cam.fov = 55
	cam.far = 3000
	current_scene.add_child(cam)
	cam.make_current()


func _shoot(views: Array) -> void:
	for v in views:
		cam.global_position = v[1]
		cam.look_at(v[2])
		await _shot(v[0])


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

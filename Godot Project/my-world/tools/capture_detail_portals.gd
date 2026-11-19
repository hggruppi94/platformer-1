extends SceneTree

# Pictures for the portal worlds' baked rock, bark, ice, snow, coral, metal and dry stone (19 Nov 2026,
# tools/build_prop_surfaces.py, scripts/detail_props.gd dress_buildings): in each world, a piece of each kind, close.
# With --old-props it shoots the same spots with everything the pipeline adds turned off, so the two sets make a
# before and after.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_detail_portals.gd -- <folder> [--old-props]
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.detail_portals_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.detail_portals_capture_backup.cfg"
const DETAIL_PROPS := preload("res://scripts/detail_props.gd")
const WORLDS := ["dark_hollow", "frozen_moment", "glenmoor", "lanternmoor", "tide_reef", "far_future", "shard_isle",
	"rhythm_springs", "rootmind"]

var out_dir := "user://detail_portals_shots"
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
	root.get_node("Clock").set("pulls_home", false)
	var detail := root.get_node("WorldDetail")
	if "--old-props" in args:
		detail.detail_props = false
		detail.batching = false
		detail.lods = false
		detail.plant_shadows = true
	var n := 1
	for world in WORLDS:
		await _open("res://scenes/portal_worlds/%s.tscn" % world)
		# The biggest piece of each kind (by its name, so the old look finds the same pieces), seen from a few metres
		var best := {}
		for mi: MeshInstance3D in current_scene.find_children("*", "MeshInstance3D", true, false):
			if not mi.is_visible_in_tree() or mi.layers == 0 or mi.mesh == null:
				continue
			var mat := mi.material_override as StandardMaterial3D
			if mat == null:
				mat = mi.mesh.surface_get_material(0) as StandardMaterial3D
			if mat == null:
				continue
			var kind := DETAIL_PROPS.surface_of(mat.resource_name, true)
			if kind == "":
				continue
			var box := mi.global_transform * mi.get_aabb()
			var size := box.size.length()
			if size > 40.0:
				continue
			if not best.has(kind) or size > best[kind][1]:
				best[kind] = [mi, size, box]
		var views := []
		for kind in best:
			var box: AABB = best[kind][2]
			var c := box.get_center()
			var r := clampf(box.size.length() * 0.5, 1.2, 8.0)
			views.append(["%02d_%s_%s" % [n, world, kind], c + Vector3(r * 1.1, r * 0.5 + 0.6, r * 1.1), c])
			n += 1
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

extends SceneTree

# Pictures for the race circuits' baked props: the grandstands, the Pumpkin Run's windmill, barn and silo, Observatory
# Hill's observatory, the Hollow Run's Moon Clock pillar and the trees, mushrooms and crystals round the roads (24 Nov
# 2026, tools/build_prop_race.py, scripts/detail_props.gd dress_race_circuit()). With --old-props it shoots the same
# spots with everything the pipeline adds turned off, so the two sets make a before and after.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_detail_race_circuits.gd -- <folder> [--old-props] [<circuit>...]
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.detail_race_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.detail_race_capture_backup.cfg"
const CIRCUITS := ["lake_loop", "meadow_wiggle", "observatory_hill", "hollow_run", "pumpkin_run"]
# Which scenery each circuit's close shot looks at, by the material of its first piece.
const SCENERY := {"lake_loop": "Crystal", "meadow_wiggle": "Mushroom Stalk", "observatory_hill": "Stalk",
	"hollow_run": "Night Bark", "pumpkin_run": "Bark"}

var out_dir := "user://detail_race_shots"
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
	root.get_node("Settings").race_intros = false
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	var detail := root.get_node("WorldDetail")
	if "--old-props" in args:
		detail.detail_props = false
		detail.batching = false
		detail.lods = false
		detail.plant_shadows = true
	for id in CIRCUITS:
		if Array(args).any(func(a): return a in CIRCUITS) and not id in args:
			continue                                               # only the circuits named after --
		await _circuit(id)
	_finish()


func _circuit(id: String) -> void:
	change_scene_to_file("res://scenes/races/%s.tscn" % id)
	for i in 16:
		await process_frame
	await create_timer(3.0).timeout
	var lw := current_scene.get_node_or_null("Mesh LODs")
	while lw and lw.busy():
		await process_frame
	var s := current_scene
	for p in s.find_children("Player", "", true, false):
		(p as Node3D).visible = false
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	cam = Camera3D.new()
	cam.fov = 55
	cam.far = 3000
	s.add_child(cam)
	cam.make_current()
	var stand := s.get_node_or_null("Stand") as Node3D
	if stand:
		var t := stand.global_transform
		await _look(id + "_1_stand", t * Vector3(-10, 5, 16), t * Vector3(0, 3, 0))
	for n in ["Windmill", "Barn", "Moon Clock"]:
		var f := s.get_node_or_null(n) as Node3D
		if f:
			var p := f.global_position
			await _look(id + "_2_" + n.to_lower().replace(" ", "_"), p + Vector3(16, 8, 16), p + Vector3(0, 6, 0))
	for g in s.get_children():
		if g is MeshInstance3D and _mat(g) == "Dome":                   # the base has the ground look by now
			var p := (g as Node3D).global_position
			await _look(id + "_2_observatory", p + Vector3(15, 3, 15), p + Vector3(0, -1, 0))
			break
	var want: String = SCENERY[id]
	for g in s.get_children():
		if g is Node3D and not (g is MeshInstance3D) and g.get_script() == null:
			var first: MeshInstance3D = null
			for c in g.get_children():
				if c is MeshInstance3D:
					first = c
					break
			if first and _mat(first) == want:
				var p := (g as Node3D).global_position
				await _look(id + "_3_scenery", p + Vector3(7, 4, 7), p + Vector3(0, 2.5, 0))
				break
	cam.queue_free()


func _mat(mi: MeshInstance3D) -> String:
	var m := mi.material_override
	if m == null and mi.mesh and mi.mesh.get_surface_count() > 0:
		m = mi.mesh.surface_get_material(0)
	return m.resource_name if m else ""


func _look(file: String, from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at)
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
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

extends SceneTree

# Close-up pictures of the Seraph's baked detail (24 Nov 2026, tools/build_prop_seraph.py, scripts/starhorn.gd _look):
# its great eye and the sunburst behind it, an eye in a wheel's bezel, its feathers, its crown of holy fire and the
# whole of it. With --old-props it shoots the same views with the detail pipeline off (the old plain shapes), so the
# two sets make a before and after.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_seraph_detail.gd -- <folder> [--old-props]
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.seraph_detail_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.seraph_detail_capture_backup.cfg"
const WORLD := "res://scenes/bosses/skyreach_trail.tscn"

var out_dir := "user://seraph_detail_shots"
var cam: Camera3D
var _had_save := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not args[0].begins_with("--"):
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(600.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	_had_save = FileAccess.file_exists(SAVE)
	if _had_save and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var game := root.get_node("Game")
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Settings").tips = false
	root.get_node("Settings").minimap = false
	root.get_node("Clock").set("pulls_home", false)
	if "--old-props" in OS.get_cmdline_user_args():
		root.get_node("WorldDetail").detail_props = false
	change_scene_to_file(WORLD)
	for i in 30:
		await process_frame
	await create_timer(2.0).timeout
	var s := current_scene as Node3D
	var top: Vector3 = s.call("summit")
	var p := s.find_child("Player", true, false) as Node3D
	p.global_position = top + Vector3(3.0, 1.0, 11.0)
	p.set("_invulnerable_timer", 999.0)          # (no fainting mid-pictures)
	await create_timer(3.0).timeout
	var boss := s.get_node("The Starhorn") as Node3D
	# Hold it still, awake and with its eyes open, so both sets show the same pose
	p.visible = false
	p.global_position = top + Vector3(0, 1.0, 40.0)
	boss.set_physics_process(false)
	await create_timer(0.6).timeout
	boss.set_process(false)
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	cam = Camera3D.new()
	cam.fov = 45
	cam.far = 3000
	s.add_child(cam)
	cam.make_current()
	var vis := boss.get_node("Visual") as Node3D
	var body := vis.get_node("Body") as Node3D
	var mid := body.global_position
	var front := vis.global_transform.basis.z.normalized()
	var side := vis.global_transform.basis.x.normalized()
	_view(mid + front * 5.2 + Vector3(0, 0.4, 0), mid)
	await _shot("01_great_eye")
	_view(mid + front * 15.0 + side * 6.0 + Vector3(0, 2.5, 0), mid + Vector3(0, 0.3, 0))
	await _shot("02_whole")
	var eyes: Array = boss.get("_parts")["eyes"]
	var wheel_eye: Node3D = eyes[1]
	var out := (wheel_eye.global_position - mid).normalized()
	_view(wheel_eye.global_position + out * 1.6 + Vector3(0, 0.3, 0), wheel_eye.global_position)
	await _shot("03_wheel_eye")
	_view(mid + side * 6.5 + front * 2.5 + Vector3(0, 1.0, 0), mid + side * 3.0 + Vector3(0, 1.0, 0))
	await _shot("04_feathers")
	var fire := body.get_node("Holy Fire") as Node3D
	_view(fire.global_position + front * 3.2 + Vector3(0, 1.4, 0), fire.global_position)
	await _shot("05_crown")
	_finish()


func _view(from: Vector3, to: Vector3) -> void:
	cam.global_position = from
	cam.look_at(to, Vector3.UP)


func _shot(file: String) -> void:
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	root.get_node("Game").hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	elif not _had_save:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	quit()

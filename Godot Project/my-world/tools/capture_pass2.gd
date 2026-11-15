extends SceneTree

# Screenshots of the overnight polish's second pass (15 Nov 2026): autumn's quest "Pumpkin Night" (the pumpkin at the
# patch, the carving spot, the lit jack-o'-lantern on the Blastoffs' porch) and the shy Peepers in three portal worlds.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_pass2.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.pass2_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.pass2_capture_backup.cfg"
const EARTH := "res://scenes/earth/earth.tscn"

var out_dir := "user://pass2_shots"
var cam: Camera3D
var _had_save := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(300.0, true, false, true).timeout.connect(_finish)
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
	game.hero["name"] = "Sofi"
	root.get_node("Settings").tips = false
	var dialogue := root.get_node("Dialogue")
	var quests := root.get_node("Quests")
	var clock := root.get_node("Clock")
	quests.state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	dialogue.set_flag("oak_woken")
	dialogue.set_flag("earth_crack_seen")
	dialogue.set_flag("cut_crack_earth")
	clock.on_earth = true
	clock.set_time(clock.day_of("autumn", 3, 1), 13 * 60.0, true)
	clock.set_earth_time(18 * 60.0 + 30, true)
	root.get_node("Portals").home_calls.enabled = false
	dialogue.set_flag("pumpkin_night_start")
	quests.check()
	game.go(EARTH, "Entrance", "")
	await _frames(90)
	await create_timer(2.0).timeout
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	_cam_in(s)
	var g := s.get_node("Pumpkin Night")
	var n := 1
	for spot in ["Pick Pumpkin", "Candle"]:
		var at := (g.get_node(spot) as Node3D).global_position
		p.global_position = at + Vector3(0, 0.6, 4.0)
		await create_timer(0.6).timeout
		_look(at + Vector3(1.8, 1.4, 2.4), at + Vector3(0, 0.3, 0))
		await _shot("%02d_pumpkin_night_%s" % [n, spot.to_lower().replace(" ", "_")])
		n += 1
	var pn := root.get_node("EarthTown/PumpkinNight")
	pn._take("pn_pumpkin", "")
	pn._take("pn_candle", "")
	quests.check()
	pn._refresh()
	var carve := (g.get_node("Carving Spot") as Node3D).global_position
	p.global_position = carve + Vector3(0, 0.6, 4.0)
	await create_timer(1.0).timeout
	_look(carve + Vector3(2.0, 1.5, 2.6), carve + Vector3(0, 0.4, 0))
	await _shot("%02d_pumpkin_night_carving" % n)
	n += 1
	pn._carve()
	quests.check()
	pn._light()
	quests.check()
	clock.set_earth_time(20 * 60.0 + 30, true)
	await create_timer(1.5).timeout
	var porch := (g.get_node("Porch") as Node3D).global_position
	p.global_position = porch + Vector3(0, 0.6, 5.0)
	await create_timer(0.8).timeout
	var lantern := g.get_node("Our Lantern") as Node3D
	var front := lantern.global_basis.z.normalized()
	_look(porch + front * 1.1 + Vector3(0, 0.6, 0) + lantern.global_basis.x * 0.3, porch + Vector3(0, 0.3, 0))
	await _shot("%02d_pumpkin_night_lantern" % n)
	n += 1
	# The Peepers
	var portals := root.get_node("Portals")
	for id in ["shard_isle", "lanternmoor", "glenmoor"]:
		var w: Dictionary = portals.world(id)
		change_scene_to_file(w.scene)
		await _frames(60)
		await create_timer(1.5).timeout
		var ws := current_scene as Node3D
		var wp := ws.find_child("Player", true, false) as CharacterBody3D
		var hud := wp.get_node_or_null("HUD")
		if hud:
			hud.visible = false
		_cam_in(ws)
		var pe := get_nodes_in_group("peepers")[0] as Node3D
		wp.global_position = pe.global_position + Vector3(0, 0.9, 12.0)
		await create_timer(1.0).timeout
		_clear_view(pe.global_position + Vector3(0, 0.3, 0), pe.global_position + Vector3(0, 0.5, 0), 2.2)
		await _shot("%02d_peeper_%s" % [n, id])
		n += 1
	_finish()


func _cam_in(s: Node) -> void:
	cam = Camera3D.new()
	cam.fov = 55
	s.add_child(cam)
	cam.make_current()


func _clear_view(body: Vector3, top: Vector3, r := 5.0) -> void:
	# Try round the person for a spot 5 m off where nothing's between the camera and them
	var space := (current_scene as Node3D).get_world_3d().direct_space_state
	var best := body + Vector3(0, 1.5, 5)
	for i in 16:
		var a := TAU * i / 16.0
		var from := body + Vector3(sin(a) * r, r * 0.28, cos(a) * r)
		var q := PhysicsRayQueryParameters3D.create(from, body)
		q.collide_with_areas = false
		var q2 := PhysicsRayQueryParameters3D.create(from, top)
		q2.collide_with_areas = false
		var hit := space.intersect_ray(q)
		if (hit.is_empty() or not hit.collider is StaticBody3D and not hit.collider is CSGShape3D) and space.intersect_ray(q2).is_empty():
			best = from
			break
	_look(best, (body + top) * 0.5)


func _look(from: Vector3, to: Vector3) -> void:
	cam.global_position = from
	cam.look_at(to, Vector3.UP)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(file: String) -> void:
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

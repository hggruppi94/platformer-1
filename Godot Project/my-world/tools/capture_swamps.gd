extends SceneTree

# Screenshots of the two swamps (scripts/swamp.gd) and the Bog Wailers (scripts/bog_wailer.gd): Lanternmoor's Mothmire
# (the way in, from above, the boardwalk and the Old Mire Hut, the lily pads and a frog, a Bog Wailer close up and
# calling its Mucklings, Glow Isle's chest) and Dusk's Embrace's Poison Mire (the way in, from above, the stepping
# stones and a Sinker Stone, a vent swelling, a poison cloud over the log bridge, a Wailer's call, the Bog Heart), and in
# both the dangers (scripts/swamp_dangers.gd: a Muck Mimic, a Snap Trap, a Lurker's eyes, the giant after you) and the
# Lookout Tree (from below and the view from the top).
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_swamps.gd -- <output folder> [lanternmoor|dusk]
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.swamps_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.swamps_capture_backup.cfg"

var out_dir := "user://swamp_shots"
var only := ""
var cam: Camera3D
var _had_save := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		only = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(400.0, true, false, true).timeout.connect(_finish)
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
	root.get_node("Settings").tips = false
	root.get_node("Settings").minimap = false
	root.get_node("Settings").set("no_damage", true)
	root.get_node("Portals").home_calls.enabled = false
	root.get_node("Clock").set("pulls_home", false)
	if only == "" or only == "lanternmoor":
		await _lanternmoor()
	if only == "" or only == "dusk":
		await _dusk()
	_finish()


func _open(path: String) -> Dictionary:
	change_scene_to_file(path)
	for i in 900:
		if current_scene != null and current_scene.scene_file_path == path:
			break
		await process_frame
	await _frames(60)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	cam = Camera3D.new()
	cam.fov = 60
	cam.far = 900
	s.add_child(cam)
	cam.make_current()
	var sw := s.get_node("Swamp") as Node3D
	for w in (sw.get("wailers") as Array):
		(w as Node).process_mode = Node.PROCESS_MODE_DISABLED     # (they stand still for the pictures till we want them)
	return {"s": s, "p": p, "sw": sw}


func _lanternmoor() -> void:
	var o := await _open("res://scenes/portal_worlds/lanternmoor.tscn")
	var p: CharacterBody3D = o.p
	var sw: Node3D = o.sw
	var isl: Array = sw.get("islands")
	var c: Vector3 = sw.get("centre")
	var lay: Dictionary = sw.get("lay")
	var away := Vector3(0, 0, 30)
	await _pose(p, Vector3(40, 0, 0), Vector3(36, 2.2, 3.0), Vector3(66, 0.5, 0), "01_mothmire_the_way_in")
	await _pose(p, away, c + Vector3(-60, 45, 50), c + Vector3(0, -4, 0), "02_mothmire_from_above")
	var hut: Vector3 = isl[2].at
	await _pose(p, away, (isl[1].at as Vector3) + Vector3(-2, 2.0, 4), hut + Vector3(4, 1.5, 0), "03_boardwalk_to_the_old_mire_hut")
	var frogs: Array = sw.get("frogs")
	if frogs.size() > 0:
		var f: Node3D = frogs[0]
		var out := (f.global_position - c).normalized()
		await _pose(p, away, f.global_position - out * 3.0 + Vector3(0, 1.6, 0), f.global_position + Vector3(0, 0.1, 0), "04_frog_and_lily_pads")
	var w: Node3D = (sw.get("wailers") as Array)[0]
	await _wailer_shots(p, sw, w, "mothmire", away)
	var chest: Node3D = sw.get("chest")
	await _pose(p, away, chest.global_position + (c - chest.global_position).normalized() * 5.0 + Vector3(0, 2.0, 0),
		chest.global_position + Vector3(0, 0.6, 0), "07_glow_isle_and_the_mire_chest")
	await _pose(p, away, (isl[3].at as Vector3) + Vector3(-3, 1.8, -7), (isl[3].at as Vector3) + Vector3(10, 0, 12), "08_mothmire_mist")
	await _danger_shots(p, sw, "20", "mothmire", away)


func _dusk() -> void:
	var o := await _open("res://scenes/scary_world/scary_world.tscn")
	var p: CharacterBody3D = o.p
	var sw: Node3D = o.sw
	var isl: Array = sw.get("islands")
	var c: Vector3 = sw.get("centre")
	var away := Vector3(0, 0, 20)
	await _pose(p, Vector3(-20, 0, 0), Vector3(-18, 2.2, 3.0), Vector3(-56, 0.5, 0), "09_poison_mire_the_way_in")
	await _pose(p, away, c + Vector3(60, 45, 50), c + Vector3(0, -4, 0), "10_poison_mire_from_above")
	var stones: Array = sw.get("stones")
	await _pose(p, away, (isl[0].at as Vector3) + Vector3(-3, 2.0, 1.5), stones[1] + Vector3(-2, 0, 2), "11_stepping_stones_and_sinkers")
	var sink: Node3D = (sw.get("sinkers") as Array)[0]
	sink.set_meta("state", "wobble")
	sink.set_meta("t", 0.1)
	await _pose(p, away, sink.global_position + Vector3(2.0, 1.4, 2.0), sink.global_position + Vector3(0, 0.3, 0), "12_a_sinker_stone_wobbling")
	var v: Node3D = (sw.get("vents") as Array)[1]
	v.set_meta("t", 5.0 - 0.3)
	await _pose(p, away, v.global_position + Vector3(3.5, 2.2, 3.5), v.global_position, "13_a_vent_swelling")
	var cl: Node3D = (sw.get("clouds") as Array)[0]
	await _pose(p, away, cl.global_position + Vector3(5, 2.5, 5), cl.global_position, "14_poison_cloud_over_the_log")
	var w: Node3D = (sw.get("wailers") as Array)[0]
	await _wailer_shots(p, sw, w, "poison_mire", away)
	var chest: Node3D = sw.get("chest")
	await _pose(p, away, chest.global_position + (c - chest.global_position).normalized() * 5.0 + Vector3(0, 2.2, 0),
		chest.global_position + Vector3(0, 0.6, 0), "17_the_bog_heart")
	await _danger_shots(p, sw, "30", "poison_mire", away)


func _wailer_shots(p: CharacterBody3D, sw: Node3D, w: Node3D, tag: String, away: Vector3) -> void:
	var face := (w.get("visual") as Node3D)
	var fwd := Vector3(sin(face.rotation.y), 0, cos(face.rotation.y))
	var n := "05" if tag == "mothmire" else "15"
	await _pose(p, away, w.global_position + fwd * 4.5 + Vector3(1.5, 2.4, 0), w.global_position + Vector3(0, 2.0, 0), "%s_bog_wailer_%s" % [n, tag])
	w.process_mode = Node.PROCESS_MODE_INHERIT
	w.call("start_call")
	await _frames(int(60 * 1.4))
	w.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(15)
	n = "06" if tag == "mothmire" else "16"
	await _pose(p, away, w.global_position + fwd * 8.0 + Vector3(3.0, 3.5, 0), w.global_position + Vector3(0, 1.2, 0), "%s_bog_wailer_calls_its_mucklings_%s" % [n, tag], Callable(), true)


func _danger_shots(p: CharacterBody3D, sw: Node3D, n: String, tag: String, away: Vector3) -> void:
	var dz := sw.get("dangers") as Node3D
	var c: Vector3 = sw.get("centre")
	# A Muck Mimic biting
	var m: Node3D = (dz.get("mimics") as Array)[0]
	var front := m.global_transform.basis.z
	p.global_position = m.global_position + front * 2.0 + Vector3(0, 1.0, 0)
	await _frames(10)
	dz.call("open_mimic", m)
	await _frames(5)
	await _pose(p, away, m.global_position + front * 3.2 + Vector3(1.2, 1.4, 0), m.global_position + Vector3(0, 0.5, 0),
		"%s_a_muck_mimic_bites_%s" % [n, tag], Callable(), true)
	for k in dz.get_children():
		if str(k.name).begins_with("Muckling"):
			k.queue_free()
	dz.process_mode = Node.PROCESS_MODE_DISABLED                   # (everything below holds still for its picture)
	# A Snap Trap open in the reeds
	var t: Node3D = (dz.get("traps") as Array)[0]
	await _pose(p, away, t.global_position + Vector3(1.8, 1.3, 1.8), t.global_position + Vector3(0, 0.2, 0), "%sb_a_snap_trap_%s" % [n, tag])
	# A Lurker's eyes over the goo
	var l: Node3D = (dz.get("lurkers") as Array)[0]
	var eyes := l.get_node("Eyes") as Node3D
	eyes.visible = true
	var cam_at := l.global_position + Vector3(3.5, 1.2, 3.5)
	eyes.rotation.y = atan2(cam_at.x - l.global_position.x, cam_at.z - l.global_position.z)
	await _pose(p, away, cam_at, l.global_position + Vector3(0, 0.2, 0), "%sc_lurker_eyes_%s" % [n, tag])
	eyes.visible = false
	# The giant after you
	var g := dz.get("giant") as Node3D
	var lair: Vector3 = dz.get("lair")
	var best: Dictionary = (sw.get("islands") as Array)[0]
	for isl: Dictionary in (sw.get("islands") as Array):
		if _flat_d(isl.at, lair) - float(isl.r) < _flat_d(best.at, lair) - float(best.r):
			best = isl
	var edge_dir := ((lair - (best.at as Vector3)) * Vector3(1, 0, 1)).normalized()
	var her: Vector3 = (best.at as Vector3) + edge_dir * maxf(float(best.r) - 1.5, 0.0)
	var dir := (her - lair) * Vector3(1, 0, 1)
	her.y = 0.0
	dir = dir.normalized() if dir.length() > 0.1 else Vector3.FORWARD
	g.global_position = Vector3(her.x, -1.0, her.z) - dir * 5.0
	g.rotation.y = atan2(dir.x, dir.z)
	p.global_position = her + Vector3(0, 1.0, 0)
	await _frames(10)
	await _pose(p, away, her + dir * 6.0 + Vector3(2.0, 3.0, 0), g.global_position + Vector3(0, 2.0, 0), "%sd_the_giant_after_you_%s" % [n, tag], Callable(), true)
	dz.process_mode = Node.PROCESS_MODE_INHERIT
	dz.call("_set_giant", "home")
	# The Lookout Tree, and the view from the top
	var lk := sw.get("lookout") as Node3D
	var out := (lk.global_position - c) * Vector3(1, 0, 1)
	out = out.normalized()
	await _pose(p, away, lk.global_position - out * 16.0 + Vector3(4, 6, 0), lk.global_position + Vector3(0, 7, 0), "%se_the_lookout_tree_%s" % [n, tag])
	var top: Vector3 = sw.get("lookout_top")
	p.global_position = top + Vector3(0, 0.9, 0)
	await _frames(20)
	await _pose(p, away, top + Vector3(0, 1.6, 0) - out * 0.5, c + Vector3(0, -6, 0), "%sf_the_view_from_the_lookout_%s" % [n, tag], Callable(), true)


func _flat_d(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _pose(p: CharacterBody3D, at: Vector3, from: Vector3, to: Vector3, file: String, then := Callable(), keep := false) -> void:
	if not keep:
		p.global_position = at + Vector3(0, 1.0, 0)
		p.velocity = Vector3.ZERO
	cam.global_position = from
	cam.look_at(to, Vector3.UP)
	await _frames(20)
	if then.is_valid():
		then.call()
		await _frames(8)
	await _shot(file)


func _frames(n: int) -> void:
	for i in n:
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

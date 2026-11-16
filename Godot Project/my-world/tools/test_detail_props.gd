extends SceneTree

# Checks the detailed props pipeline in Stars Hollow (15 Nov 2026):
# - scripts/detail_props.gd: every builder street lamp, park bench and the gazebo has its detailed model, the old
#   pieces are still there (collision, names) but no longer drawn, and the gazebo keeps its bulbs, lights and label,
# - scripts/static_batch.gd: still builder pieces are merged into far fewer meshes, nothing with a name or a script is
#   touched, merged pieces stay in the tree and still solid, and far townsfolk fade out,
# - scripts/town_occluders.gd: an occluder in every plain building, none in buildings you go into, and they switch
#   off when the camera's inside one,
# - with WorldDetail's switches off, Stars Hollow is exactly as before (nothing hidden, nothing added).
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_detail_props.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.detail_props_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.detail_props_test_backup.cfg"
const EARTH := "res://scenes/earth/earth.tscn"
const STATIC_BATCH := preload("res://scripts/static_batch.gd")

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(300.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var game := root.get_node("Game")
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Settings").tips = false
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.on_earth = true
	clock.set_earth_time(12 * 60.0, true)
	var detail := root.get_node("WorldDetail")

	# --- Everything off: Stars Hollow as it was
	detail.detail_props = false
	detail.batching = false
	detail.occluders = false
	change_scene_to_file(EARTH)
	await _frames(16)
	await create_timer(3.5).timeout              # WorldDetail merges again 1 s and 3 s in, and the rare fish come
	var s := current_scene
	var drawn_before := _drawn(s)
	var hidden := 0
	for n in s.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).layers == 0:
			hidden += 1
	check(hidden == 0, "with the switches off nothing is taken out of drawing (%d)" % hidden)
	check(s.find_child("Detailed Lamp 0", true, false) == null and s.get_node_or_null("Town Occluders") == null,
		"with the switches off nothing is added")
	var poles := _poles(s)
	var named_before := _named(s)
	var bodies_before := s.find_children("*", "CollisionShape3D", true, false).size()

	# --- Everything on (the game's default)
	detail.detail_props = true
	detail.batching = true
	detail.occluders = true
	change_scene_to_file(EARTH)
	await _frames(16)
	await create_timer(3.5).timeout              # WorldDetail merges again 1 s and 3 s in, and the rare fish come
	s = current_scene
	var props: Dictionary = detail.last_props
	var batch: Dictionary = detail.last_batch
	print("props ", props, "  batch ", batch)
	check(ResourceLoader.exists("res://models/props/street_lamp.glb"), "the street lamp model is imported")
	check(props.get("lamps", 0) == poles and poles >= 30, "every street lamp has its detailed model (%d of %d)" % [props.get("lamps", 0), poles])
	check(props.get("benches", 0) >= 5, "the park benches have theirs (%d)" % props.get("benches", 0))
	check(props.get("gazebo", 0) == 1, "and the gazebo")
	var gz := s.get_node("Gazebo")
	check(gz.get_node_or_null("Detailed Gazebo") != null, "the detailed gazebo stands in the Gazebo")
	var lit := gz.get_node_or_null("Gazebo Lights") as Node3D
	check(lit != null and lit.get_child_count() >= 32, "its string of bulbs and lights is still there")
	var label_ok := false
	for c in gz.get_children():
		if c is Label3D and (c as Label3D).text == "Town Green":
			label_ok = true
	check(label_ok, "and its Town Green sign")
	var old_drawn := 0
	for n in gz.get_children():
		if n is MeshInstance3D and (n as MeshInstance3D).has_meta("detail_prop_old") and (n as MeshInstance3D).layers != 0:
			old_drawn += 1
	check(old_drawn == 0, "the old gazebo pieces aren't drawn")
	check(s.find_children("*", "CollisionShape3D", true, false).size() == bodies_before,
		"every collision shape is still there (%d)" % bodies_before)
	var named_after := _named(s)
	var lost := 0
	for k in named_before:
		if not named_after.has(k):
			lost += 1
			if lost <= 8:
				print("  missing: ", k)
	check(lost == 0, "every named node is still there (%d missing)" % lost)
	for l in s.get_node("Street Lamps").get_children():
		if l is OmniLight3D:
			check(l.is_in_group("earth_lamps"), "lamp lights still come on at night")
			break
	# Standing on the gazebo: the old deck's collision holds you up
	var q := PhysicsRayQueryParameters3D.create(Vector3(1.5, 5, 1.0), Vector3(1.5, -2, 1.0))
	var hit := (s as Node3D).get_world_3d().direct_space_state.intersect_ray(q)
	check(hit and absf(hit.position.y - 0.6) < 0.05, "the gazebo's deck is solid at 0.6 m")

	# Batching
	check(batch.get("pieces", 0) > 1500 and batch.get("meshes", 0) < batch.get("pieces", 0) / 3,
		"still pieces are merged (%d pieces into %d meshes)" % [batch.get("pieces", 0), batch.get("meshes", 0)])
	var drawn_after := _drawn(s)
	check(drawn_after < drawn_before * 0.7, "far fewer meshes are drawn (%d, was %d)" % [drawn_after, drawn_before])
	var scripted_touched := 0
	for n in s.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.has_meta("static_batch") and mi.layers == 0:
			var p := mi.get_parent()
			while p and p != s:
				if p.get_script() != null and not (p.get_script().resource_path in STATIC_BATCH.SAFE_SCRIPTS):
					scripted_touched += 1
					break
				p = p.get_parent()
	check(scripted_touched == 0, "nothing under a node with a script is merged (%d)" % scripted_touched)
	check(batch.get("people_faded", 0) > 50, "far townsfolk fade out (%d meshes)" % batch.get("people_faded", 0))

	# Occluders
	var occ := s.get_node_or_null("Town Occluders")
	check(occ != null and occ.get_child_count() >= 12, "occluders in the town's buildings (%d)" % (occ.get_child_count() if occ else 0))
	if occ:
		check(occ.get_node_or_null("Town Hall") == null and occ.get_node_or_null("Lantern Hill Library") == null
			and occ.get_node_or_null("Dance Studio") == null, "none in buildings you can go into")
		var o := occ.get_child(0) as OccluderInstance3D
		var cam := Camera3D.new()
		s.add_child(cam)
		cam.make_current()
		cam.global_position = o.global_position
		await _frames(2)
		check(not o.visible, "an occluder switches off with the camera inside it")
		cam.global_position = o.global_position + Vector3(40, 10, 40)
		await _frames(2)
		check(o.visible, "and back on outside")
	print("RESULT " + ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	_finish()


func _poles(s: Node) -> int:
	var n := 0
	for c in s.get_node("Street Lamps").get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is CylinderMesh:
			n += 1
	return n


func _drawn(s: Node) -> int:
	var n := 0
	for c in s.find_children("*", "GeometryInstance3D", true, false):
		var g := c as GeometryInstance3D
		if g.is_visible_in_tree() and g.layers != 0:
			n += 1
	return n


func _named(s: Node) -> Dictionary:
	var out := {}
	for n in s.find_children("*", "", true, false):
		# (paths through a made-at-load-time "@Node3D@123" can differ between loads, so they're left out)
		# (people and the player change what they hold with the time of day, and aren't touched here)
		var path := String(s.get_path_to(n))
		if not path.contains("@") and not path.begins_with("Characters/") and not path.begins_with("Player/"):
			out[path] = true
	return out


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	else:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	quit(0 if failures == 0 else 1)

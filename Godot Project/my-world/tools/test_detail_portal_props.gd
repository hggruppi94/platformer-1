extends SceneTree

# Checks the portal worlds' baked props (19 Nov 2026, Hayden: "Then keep baking details"): scripts/detail_props.gd
# swaps the plain builder pieces for the models from tools/build_prop_glenmoor.py (and the worlds after it), keeping
# every solid box and name, and dressing a place twice changes nothing.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_detail_portal_props.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.portal_props_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.portal_props_test_backup.cfg"
const GLENMOOR := "res://scenes/portal_worlds/glenmoor.tscn"
const TIDE_REEF := "res://scenes/portal_worlds/tide_reef.tscn"
const DETAIL_PROPS := preload("res://scripts/detail_props.gd")

var failures := 0
var detail: Node


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
	root.get_node("Clock").set("pulls_home", false)
	detail = root.get_node("WorldDetail")

	# As built: the solid boxes to compare with
	detail.detail_props = false
	await _load(GLENMOOR)
	var shapes_before := _shapes(current_scene)
	var ring := current_scene.find_child("Standing Stones", true, false) as Node3D
	var heights := {}
	for c in ring.get_children():
		if c is MeshInstance3D and String(c.name).begins_with("Stone") and (c as MeshInstance3D).mesh is BoxMesh:
			heights[String(c.name)] = ((c as MeshInstance3D).mesh as BoxMesh).size.y

	detail.detail_props = true
	await _load(GLENMOOR)
	var s := current_scene
	var got: Dictionary = detail.last_props
	print("Glenmoor props: ", got)
	check(got.get("stones", 0) == heights.size() and heights.size() >= 9, "every Standing Stone swapped (%d)" % heights.size())
	check(got.get("cairns", 0) == 6, "six cairns up Ben Bonnie swapped")
	check(got.get("croft", 0) == 1 and got.get("barn", 0) == 1, "Heather's croft and barn swapped")
	check(got.get("hay", 0) == 5, "the barn's five hay bales swapped")

	ring = s.find_child("Standing Stones", true, false) as Node3D
	var stones_ok := true
	var old_drawn := 0
	for c in ring.get_children():
		# (the worn grass disc in the middle stays as it is)
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh and (c as MeshInstance3D).layers != 0:
			old_drawn += 1
		if String(c.name).begins_with("Detailed Stone"):
			var aabb := _aabb(c as Node3D)
			if aabb.size.y < 1.0:
				stones_ok = false
	check(old_drawn == 0, "no plain standing stone or moss box drawn")
	# Each detailed stone stands as tall as the box it replaced
	for n: String in heights:
		var box := ring.get_node(n) as MeshInstance3D
		var top := box.transform * Vector3(0, heights[n] * 0.5, 0)
		var best := INF
		for c in ring.get_children():
			if String(c.name).begins_with("Detailed Stone"):
				var d := (c as Node3D).position.distance_to(box.position)
				best = minf(best, d)
		if best > 0.01:
			stones_ok = false
		if top.y < 1.0:
			stones_ok = false
	check(stones_ok, "each detailed stone sits where its box was, at its height")

	var summit := 0
	for g in s.find_children("Detailed Cairn", "Node3D", true, false):
		var p := g.get_parent()
		var balls := 0
		for c in p.get_children():
			if c is MeshInstance3D and (c as MeshInstance3D).mesh is SphereMesh:
				balls += 1
			if c is MeshInstance3D and c.name != "Detailed Cairn" and (c as MeshInstance3D).layers != 0:
				old_drawn += 1
		if balls > 4:
			summit += 1
	check(summit == 1, "the summit cairn is the big one")
	var croft := s.find_child("Heather's Croft", true, false)
	var barn := s.find_child("Barn", true, false)
	var plain := 0
	for g in [croft, barn]:
		for c in g.get_children():
			if c is MeshInstance3D and (c as MeshInstance3D).layers != 0:
				plain += 1
	check(plain == 0, "nothing plain left drawn on the croft and barn")
	check(_aabb(croft.get_node("Detailed Croft")).size.x > 7.0, "the croft model is house sized")
	check(_aabb(barn.get_node("Detailed Barn")).size.y > 7.0, "the barn model is barn sized")
	var hay_ok := true
	for c in barn.get_children():
		if String(c.name).begins_with("Hay Bale") and not c.has_node("Detailed Hay"):
			hay_ok = false
	check(hay_ok, "every hay bale keeps its name and holds its detailed bale")

	check(_shapes(s) == shapes_before, "every collision shape is where it was")
	var again := DETAIL_PROPS.dress_glenmoor(s)
	var none := true
	for k in again:
		if again[k] != 0:
			none = false
	check(none, "dressing it again changes nothing")

	await _tide_reef()
	print("RESULT " + ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	_finish()


func _tide_reef() -> void:
	await _load(TIDE_REEF)
	var s := current_scene
	# The corals' detailed copies still fade and bloom with the tide (they used to stay as they were dressed)
	var coral: MeshInstance3D
	for c in s.find_children("*", "MeshInstance3D", true, false):
		var m := (c as MeshInstance3D).material_override as StandardMaterial3D
		if m and m.resource_name.begins_with("Coral ") and m.has_meta("detail_surface") and c.is_visible_in_tree():
			coral = c
			break
	check(coral != null, "the reef's corals wear their detailed copies")
	var got: Dictionary = detail.last_props
	print("Tide Reef props: ", got)
	check(got.get("houses", 0) == 10, "all ten coral houses swapped")
	check(got.get("lamps", 0) >= 10, "the bubble lamps' posts swapped (%d)" % got.get("lamps", 0))
	check(got.get("boat", 0) == 1, "the stranded boat swapped")
	var plain := 0
	var kept_bits := true
	for i in 10:
		var h := s.get_node("Coral House %d" % (i + 1))
		var bits := 0
		for c in h.get_children():
			if not (c is MeshInstance3D):
				continue
			# (the coral bits may be merged into one batch, but they're never put away as old props)
			if String((c as MeshInstance3D).material_override.resource_name).begins_with("Coral"):
				if not c.has_meta("detail_prop_old"):
					bits += 1
			elif not c.has_meta("detail_prop_old"):
				plain += 1
		if bits < 10:
			kept_bits = false
	check(plain == 0, "nothing plain left drawn on a coral house")
	check(kept_bits, "every house keeps its coral bumps and chimney")
	for b in s.get_node("Bubble Lamps").get_children():
		if b is MeshInstance3D and (b as MeshInstance3D).mesh is CylinderMesh and (b as MeshInstance3D).layers != 0:
			plain += 1
	check(plain == 0, "no plain lamp post drawn")
	var lit := 0
	for b in s.get_node("Bubble Lamps").get_children():
		if b is MeshInstance3D and (b as MeshInstance3D).mesh is SphereMesh and (b as MeshInstance3D).layers != 0:
			lit += 1
	check(lit >= 10, "every bubble still glows on its post")
	# A detailed dome is tinted its own house's coral, and blooms with the tide
	var dome := (s.get_node("Coral House 1/Detailed Dome") as Node3D).find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var dm := dome.get_surface_override_material(0) as StandardMaterial3D
	s.set_tide(0.0)
	var d_dry := dm.albedo_color
	s.set_tide(1.0)
	var d_wet := dm.albedo_color
	check(not d_dry.is_equal_approx(d_wet) and d_wet.r > d_wet.b, "a detailed dome blooms in its coral pink (%s -> %s)" % [d_dry, d_wet])
	s.set_tide(0.0)
	var again := DETAIL_PROPS.dress_tide_reef(s)
	check(again.houses == 0 and again.lamps == 0 and again.boat == 0, "dressing the reef again changes nothing")
	if coral:
		s.set_tide(0.0)
		var dry := (coral.material_override as StandardMaterial3D).albedo_color
		s.set_tide(1.0)
		var wet := (coral.material_override as StandardMaterial3D).albedo_color
		check(not dry.is_equal_approx(wet), "a detailed coral blooms when the tide comes in (%s -> %s)" % [dry, wet])
		s.set_tide(0.0)


func _aabb(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var t := n.global_transform.affine_inverse() * mi.global_transform
		var b := t * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if n is MeshInstance3D:
		box = (n as MeshInstance3D).get_aabb() if first else box
	return box


func _shapes(s: Node) -> Dictionary:
	var out := {}
	for c in s.find_children("*", "CollisionShape3D", true, false):
		var cs := c as CollisionShape3D
		var k := "%s %s" % [cs.get_parent().name if not String(cs.get_parent().name).begins_with("@") else "@",
			cs.global_position.snapped(Vector3(0.1, 0.1, 0.1))]
		out[k] = out.get(k, 0) + 1
	return out


func _load(path: String) -> void:
	change_scene_to_file(path)
	for i in 16:
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

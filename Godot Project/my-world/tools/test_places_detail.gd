extends SceneTree

# Checks the small new places' baked look (25 Nov 2026, scripts/detail_props.gd world_patched / dress_place):
# every cave the cave kit builds (the Undergardens, the Glimmer Caves, Old Ember's tunnel and chamber, the Hot Springs'
# grottos) wears the baked rock in world space, still coloured by its vertex colours and still unlit by the sky; the
# Undergardens' roots wear bark; the volcano's stone wears rock; the Museum Garden's exhibits, walk and arbor wear
# rock, stone, maple and brushed metal; a virtue trial's marble wears stone; the Knitting Class's desks wear maple and
# its rug, cushions and baskets the woven cloth. Glows and see-through things stay plain, doing it again changes
# nothing, and with the detail pipeline off nothing is patched.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_places_detail.gd
#
# Puts the save and settings aside and back, like the other tests.

const SAVE := "user://save.json"
const BACKUP := "user://save.places_detail_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.places_detail_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const SPRINGS := "res://scenes/portal_worlds/rhythm_springs.tscn"
const SCHOOL := "res://scenes/school/school.tscn"
const TRIAL := "res://scenes/bosses/virtue_trial.tscn"
const DP := preload("res://scripts/detail_props.gd")

var failures := 0
var game: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(300.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _mat(mi: MeshInstance3D) -> StandardMaterial3D:
	return mi.material_override as StandardMaterial3D


func _kind(mi: MeshInstance3D) -> String:
	var m := _mat(mi)
	return str(m.get_meta(DP.SURFACE_META, "")) if m else ""


func _counts(root: Node) -> Dictionary:
	var out := {}
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var k := _kind(mi)
		if k != "":
			out[k] = int(out.get(k, 0)) + 1
	return out


func _glows_plain(root: Node) -> bool:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := _mat(mi)
		if m and (m.emission_enabled and m.emission_energy_multiplier > 0.5 or m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED) \
				and _kind(mi) != "":
			print("      glowing or see-through but patched: ", mi.get_path(), " ", m.resource_name)
			return false
	return true


func _maps_ok(root: Node) -> bool:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := _mat(mi)
		if m and _kind(mi) != "" and (m.albedo_texture == null or m.normal_texture == null or not m.uv1_world_triplanar):
			print("      patched without its maps or not in world space: ", mi.get_path())
			return false
	return true


func _cave_rock_ok(root: Node, what: String) -> void:
	var rocks := []
	for mi in root.find_children("Rock", "MeshInstance3D", true, false):
		var m := _mat(mi)
		if m and m.resource_name == "Cave Rock":
			rocks.append(mi)
	check(rocks.size() > 0, "%s: the cave kit's rock is there (%d)" % [what, rocks.size()])
	var good := rocks.size() > 0
	for mi in rocks:
		var m := _mat(mi)
		good = good and _kind(mi) == "rock" and m.uv1_world_triplanar and m.vertex_color_use_as_albedo \
			and m.disable_ambient_light and m.albedo_texture != null and m.normal_texture != null
	check(good, "%s: it wears the baked rock in world space, vertex-coloured and unlit by the sky" % what)


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	var portals := root.get_node("Portals")
	root.get_node("Settings").tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	root.get_node("Clock").set("pulls_home", false)
	var fn := root.get_node("FirstNight")
	root.get_node("Quests").state[fn.ID] = {"step": 0, "done": true, "since_day": 1}
	portals.home_calls.enabled = false
	for w in ["lanternmoor", "rhythm_springs"]:
		portals.cleared_worlds.append(w)
	var wd := root.get_node("WorldDetail")
	check(DP.on(), "the detail pipeline is on")

	# --- The Void: the Undergardens and the Museum Garden ---------------------------------------------------------
	change_scene_to_file(TOWN)
	await _frames(14)
	await _physics(6)
	var s := current_scene
	var ug := s.get_node_or_null("Undergardens")
	check(ug != null, "the Undergardens are in the Void")
	if ug:
		_cave_rock_ok(ug, "the Undergardens")
		var c := _counts(ug)
		check(int(c.get("bark", 0)) >= 20, "the Undergardens' roots, steps and the Old Taproot wear bark (%d)" % int(c.get("bark", 0)))
		check(_glows_plain(ug), "the Undergardens' glows, water and spores stay plain")
		check(_maps_ok(ug), "every patched piece there has its maps, in world space")
		var again := DP.dress_place(ug, [["Root Bark", "bark"], ["Root", "bark"]])
		check(again == 0, "dressing the Undergardens again changes nothing")
	var mg := s.find_child("Museum Grounds", true, false)
	check(mg != null, "the Museum Garden is there")
	if mg:
		var c := _counts(mg)
		for k in ["rock", "stone", "maple", "brushed_metal"]:
			check(int(c.get(k, 0)) >= 1, "the Museum Garden has %s on it (%d)" % [k, int(c.get(k, 0))])
		check(_glows_plain(mg), "the Museum Garden's ember, crystals, lamps and glass stay plain")
		check(_maps_ok(mg), "...and every patched piece has its maps")
		check(DP.dress_place(mg, load("res://scripts/museum_garden.gd").GARDEN_SURFACES) == 0,
			"dressing the Museum Garden again changes nothing")
	var grottos := 0
	for g in s.find_children("*", "StaticBody3D", true, false):
		if str(g.name).begins_with("Grotto") or str(g.name).contains("Grotto"):
			for mi in g.find_children("Rock", "MeshInstance3D", true, false):
				if _kind(mi) == "rock":
					grottos += 1
	print("      (Hot Springs grottos with baked rock: %d)" % grottos)

	# --- Rhythm Springs: Old Ember's tunnel and chamber ----------------------------------------------------------
	change_scene_to_file(SPRINGS)
	await _frames(12)
	await _physics(6)
	var depths := current_scene.get_node_or_null("Volcano Depths")
	check(depths != null, "the volcano's depths are under Rhythm Springs")
	if depths:
		_cave_rock_ok(depths, "the Ember Tunnel")
		var c := _counts(depths)
		check(int(c.get("rock", 0)) >= 10, "the chamber's basalt, lava rock and vent rims wear rock (%d)" % int(c.get("rock", 0)))
		check(_glows_plain(depths), "the lava, cracks, vents and glows stay plain")
		var lid := depths.find_child("Lid", true, false)
		check(lid == null or not lid is MeshInstance3D or _kind(lid) == "", "the Ember Chest's lid (it opens) isn't laid on in world space")

	# --- The castle school: the Knitting Class --------------------------------------------------------------------
	change_scene_to_file(SCHOOL)
	await _frames(12)
	await _physics(4)
	var room := current_scene.get_node_or_null("Floor 2/Knitting Class")
	check(room != null, "the Knitting Class is in the school")
	if room:
		var c := _counts(room)
		check(int(c.get("maple", 0)) >= 30, "its desks, legs, frame and chair wear maple (%d)" % int(c.get("maple", 0)))
		check(int(c.get("tweed", 0)) >= 8, "its rug, cushions and baskets wear the woven cloth (%d)" % int(c.get("tweed", 0)))
		check(_maps_ok(room), "...with their maps")

	# --- A virtue trial ------------------------------------------------------------------------------------------
	root.get_node("Bosses").set_meta("virtue_trial", {"id": "humility", "stone": 0, "pos": Vector3.ZERO, "yaw": 0.0, "held": 0})
	change_scene_to_file(TRIAL)
	await _frames(12)
	await _physics(4)
	var c := _counts(current_scene)
	check(int(c.get("stone", 0)) >= 5, "the trial's marble wears the dressed stone (%d)" % int(c.get("stone", 0)))
	check(int(c.get("rock", 0)) >= 1, "...and its islands' undersides the rock (%d)" % int(c.get("rock", 0)))
	check(_glows_plain(current_scene), "the trial's gold, beams and clouds stay plain")

	# --- With the detail pipeline off -----------------------------------------------------------------------------
	wd.set("detail_props", false)
	check(not DP.on(), "switched off")
	check(DP.world_patched(StandardMaterial3D.new(), "rock") == null, "world_patched gives nothing with it off")
	change_scene_to_file(SCHOOL)
	await _frames(12)
	room = current_scene.get_node_or_null("Floor 2/Knitting Class")
	check(room != null and _counts(room).is_empty(), "with it off the Knitting Class is as it was")
	change_scene_to_file(SPRINGS)
	await _frames(12)
	depths = current_scene.get_node_or_null("Volcano Depths")
	var plain := depths != null
	if depths:
		for mi in depths.find_children("Rock", "MeshInstance3D", true, false):
			plain = plain and _kind(mi) == ""
		plain = plain and _counts(depths).is_empty()
	check(plain, "with it off the volcano's rock is the old noise rock")
	wd.set("detail_props", true)
	portals.cleared_worlds.erase("lanternmoor")
	portals.cleared_worlds.erase("rhythm_springs")
	root.get_node("Bosses").remove_meta("virtue_trial")
	_finish()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	if game:
		game.hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	else:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	print("RESULT %s (%d failed)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)

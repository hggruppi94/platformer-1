extends SceneTree

# Checks Hayden's 14 Nov 2026 evening playtest fixes (thread "Fix bugs from the 14 Nov evening playtest"):
#   - the school's floors (the ones with a hole: over the library, the offices, the hidden stair) are drawn from both
#     sides under the ground look (scripts/world_detail.gd), so you can't see through them from above
#   - nothing of the view's hill runs through the lower level (the Logia's "invisible plane"), and the Sky
#     Pavilion's doorway has its frame, lights and awning (tools/build_school.gd)
#   - a grind stops at a wall instead of carrying her through it (scenes/player/skate.gd _wall_in_way)
#   - a friend's copy walking with you hides while the place has that friend in it already (scripts/party.gd)
#   - the wardrobe shows a picture of who you're dressing, made again as you change things (scripts/shop.gd)
# (The snowman spots, Nina's big snowball and the hayride's talk spot are in test_winter and test_festival.)
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_playtest_nov14c.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.nov14c_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.nov14c_test_backup.cfg"
const SCHOOL := "res://scenes/school/school.tscn"
const PARK := "res://scenes/skate/test_park.tscn"
const LOW_Y := -6.0                         # build_school.gd LOW_Y

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


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	root.get_node("Settings").tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game.riding = false
	root.get_node("Clock").set("pulls_home", false)
	root.get_node("Quests").state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	change_scene_to_file(SCHOOL)
	await _frames(8)
	await _physics(4)
	_check_school()
	await _check_doubles()
	await _check_wardrobe()
	await _check_grind_wall()
	_finish()


func _check_school() -> void:
	var school := current_scene
	# Floors with a hole in them, under the ground look: drawn from both sides
	var floors := 0
	var two_sided := 0
	for body in school.find_children("*", "StaticBody3D", true, false):
		if not str(body.name) in ["Gallery Floor", "Office Floor", "Stair Floor"]:
			continue
		for mi in body.find_children("*", "MeshInstance3D", true, false):
			floors += 1
			var m: Material = (mi as MeshInstance3D).material_override
			if m == null:
				m = (mi as MeshInstance3D).get_surface_override_material(0)
			if m is ShaderMaterial:
				if (m as ShaderMaterial).shader.code.contains("cull_disabled"):
					two_sided += 1
			elif m is BaseMaterial3D and (m as BaseMaterial3D).cull_mode == BaseMaterial3D.CULL_DISABLED:
				two_sided += 1
	check(floors >= 3 and two_sided == floors, "the floors with holes are drawn from both sides (%d of %d)" % [two_sided, floors])
	# Nothing round and big (the view's hill) has a lid at the lower level's height
	var lids := []
	for mi in school.find_children("*", "MeshInstance3D", true, false):
		var cyl := (mi as MeshInstance3D).mesh as CylinderMesh
		if cyl == null or maxf(cyl.top_radius, cyl.bottom_radius) < 30.0:
			continue
		var y := (mi as Node3D).global_position.y
		var top := y + cyl.height / 2
		var bottom := y - cyl.height / 2
		if (cyl.cap_top and top > LOW_Y and top < 0.5) or (cyl.cap_bottom and bottom > LOW_Y and bottom < 0.5):
			lids.append(mi.name)
	check(lids.is_empty(), "no hill top runs through the lower level %s" % str(lids))
	var door := school.find_child("Pavilion Door", true, false)
	check(door != null and door.find_child("Door Frame", true, false) != null and door.find_child("Door Lights", true, false) != null \
		and door.find_child("Awning", true, false) != null, "the Sky Pavilion's doorway has a frame, lights and an awning")


func _check_doubles() -> void:
	var party := root.get_node("Party")
	party.joined = ["bramble"]
	party.with_you = "bramble"
	await _physics(30)
	var fols: Array = party.followers()
	check(fols.size() == 1 and (fols[0] as Node3D).is_visible_in_tree(), "Bramble's copy walks with you in the school")
	# Something else puts Bramble here too (a cutscene, a quest): the copy steps aside, and comes back after
	var other := (load("res://models/characters/plant_girl.glb") as PackedScene).instantiate() as Node3D
	other.set_meta("model_source", "res://models/characters/plant_girl.glb")
	current_scene.add_child(other)
	await _wait(2.6)
	check(not fols.is_empty() and not (fols[0] as Node3D).is_visible_in_tree() and party.doubles().is_empty(),
		"...and steps aside while there's another Bramble here (no two at once)")
	other.queue_free()
	await _wait(2.6)
	check(not fols.is_empty() and is_instance_valid(fols[0]) and (fols[0] as Node3D).is_visible_in_tree(),
		"...and comes back when she's gone")
	party.with_you = ""
	party.joined = []
	await _physics(10)


func _check_wardrobe() -> void:
	var shop := root.get_node("Shop")
	for id in ["sk8_beanie", "galaxy_tee"]:
		if not game.has_item("shop:" + id):
			game.items.append("shop:" + id)
	game.outfits["hero"] = {}
	shop.open("Wardrobe")
	await _frames(3)
	var holder := shop.get("_preview") as Control
	var model := _preview_model(holder)
	check(holder != null and holder.visible and model != null, "the wardrobe shows a picture of your hero")
	check(model != null and model.find_child("Hat", true, false) == null, "...as they are, with no hat")
	shop.cycle("head", 1)
	await _frames(3)
	var model2 := _preview_model(holder)
	check(model2 != null and model2 != model and model2.find_child("Hat", true, false) != null,
		"...and putting a hat on shows it on the picture")
	shop.cycle_who(1)
	await _frames(3)
	var friend := _preview_model(holder)
	check(friend != null and friend != model2, "...and picking a friend shows them")
	shop.close()
	shop.open("Gadget")
	await _frames(2)
	check(not holder.visible, "...and other stalls have no picture")
	shop.close()
	await _frames(2)


func _preview_model(holder: Control) -> Node3D:
	if holder == null:
		return null
	for n in holder.find_children("Model", "Node3D", true, false):
		if not n.is_queued_for_deletion():
			return n as Node3D
	return null


func _check_grind_wall() -> void:
	game.riding = true
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	change_scene_to_file(PARK)
	await _frames(6)
	await _physics(6)
	var p := current_scene.find_child("Player", true, false) as CharacterBody3D
	var s := p.get_node("Skate")
	p.global_position = Vector3(-30, 1.2, 38)
	await _physics(4)
	var wall := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 4, 0.4)
	cs.shape = box
	wall.add_child(cs)
	current_scene.add_child(wall)
	wall.global_position = p.global_position + Vector3(0, 1, -1.5)
	await _physics(2)
	check(s._wall_in_way(Vector3(0, 0, -2.5)), "riding a rail into a wall: the wall's in the way")
	check(not s._wall_in_way(Vector3(0, 0, 2.5)), "...and riding away from it, nothing is")
	check(not s._wall_in_way(Vector3(2.5, 0, 0)), "...and along it, nothing is")
	wall.queue_free()
	game.riding = false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


func _finish() -> void:
	if root.has_node("Shop") and root.get_node("Shop").is_open():
		root.get_node("Shop").close()
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

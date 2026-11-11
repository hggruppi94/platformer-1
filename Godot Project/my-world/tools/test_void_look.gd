extends SceneTree

# Checks the hero's Void look (scripts/void_look.gd): on Earth they look as made (no feature, no glow, no extra watch);
# their first time in the Void they get a feature at random and hear about it; in the Void their eyes glow, their watch
# is on their left wrist (not before they have one, not twice when they wear it, the Time Keeper once they have it)
# and their feature's on; every feature and glow colour goes on; going home to Earth takes it all off again; the
# Earth race circuit counts as Earth and a Void one as the Void; the creator's Void tab only shows once they've been,
# picks a feature and colour, shows it off on Earth while it's open and takes it off after; Surprise me and Start
# over keep it; and it saves and loads.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_void_look.gd
#
# Your own save is put aside and put back at the end.

const VOID_LOOK := preload("res://scripts/void_look.gd")
const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const EARTH := "res://scenes/earth/earth.tscn"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0
var game: Node
var creator: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(150.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	game = root.get_node("Game")
	creator = root.get_node("Creator")
	game.hold_saves = true

	# --- A hero who's never been to the Void, at home on Earth ---
	var h := Hero.blank(true)
	h.name = "Sam"
	game.hero = h
	game.needs_creator = false
	game.items.clear()
	game.outfits = {"hero": {}}
	game._resume = {}
	game.next_spawn = "HomeSpawn"
	change_scene_to_file(EARTH)
	await _frames(6)
	var p := current_scene.find_child("Player", true, false) as Node3D
	check(not VOID_LOOK.in_void(p), "Stars Hollow isn't the Void")
	check(not VOID_LOOK.has_look(game.hero), "a hero who's never been to the Void has no Void feature yet")
	check(_pieces(p).is_empty() and not _eyes_glow(p), "on Earth they look just as they were made")
	creator.open()
	await _frames(2)
	check(not "Void" in creator.tabs(), "the creator has no Void tab before they've been to the Void")
	creator._tab = "Name"
	creator.close()
	await _frames(2)

	# --- Their first time in the Void (they have the Shift Watch by now: it appears on the first crossing) ---
	game.items.append("shop:shift_watch")
	change_scene_to_file(TOWN)
	await _frames(6)
	p = current_scene.find_child("Player", true, false) as Node3D
	check(VOID_LOOK.in_void(p), "the Void town is the Void")
	check(VOID_LOOK.has_look(game.hero), "their first time in the Void, they get a feature")
	var feature := VOID_LOOK.feature(game.hero)
	check(_eyes_glow(p), "their eyes glow in the Void")
	check(_piece(p, "watch") != null, "their watch is on their left wrist")
	check(_piece(p, feature) != null, "and their %s are on" % feature)
	var said := []
	game.message_posted.connect(func(t: String) -> void:
		if "changed in the Void" in t:
			said.append(t))
	await create_timer(5.6).timeout
	check(said.size() == 1 and VOID_LOOK.FEATURE_NAMES[feature].to_lower() in said[0],
		"they hear they've changed (and what they've got), a few seconds after landing")
	var bone := (_piece(p, "watch") as BoneAttachment3D).bone_name
	check(bone == "hand.L", "the watch rides the left hand")
	check(_piece(p, "tail") == null or feature == "tail", "only their own feature is on")

	# --- Every feature and colour ---
	for f in VOID_LOOK.FEATURES:
		game.hero["void_feature"] = f
		game.equipment_changed.emit()
		await _frames(1)
		var holder := _piece(p, f)
		var others := _pieces(p).filter(func(n: Node) -> bool: return n.name != VOID_LOOK.HOLDER + " " + f and n.name != VOID_LOOK.HOLDER + " watch")
		check(holder != null and holder.get_child(0).find_children("Tip*", "MeshInstance3D", true, false).size() > 0
			and others.is_empty(), "%s: on, with glowing tips, and nothing else" % f)
		if f == "tail":
			check(holder.bone_name == "hips", "the tail grows from their hips")
		else:
			check(holder.bone_name == "head", "%s ride their head" % f)
	for k in VOID_LOOK.GLOWS.size():
		game.hero["void_glow"] = k
		game.equipment_changed.emit()
		await _frames(1)
		var tip := _piece(p, "tail").find_children("Tip", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var m := tip.material_override as StandardMaterial3D
		check(m.emission_enabled and m.emission.is_equal_approx(VOID_LOOK.GLOWS[k]), "glow colour %s lights the tip" % VOID_LOOK.GLOW_NAMES[k])
	var tail_skin := (_piece(p, "tail").find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).material_override as StandardMaterial3D
	check(tail_skin.albedo_color.is_equal_approx(VOID_LOOK.skin_color(p.get("model"))), "the tail's their own skin colour")

	# --- Watches ---
	game.outfits["hero"] = {"hands": "shift_watch"}
	game.equipment_changed.emit()
	await _frames(1)
	check(_piece(p, "watch") == null, "wearing the Shift Watch already: no second watch")
	game.outfits["hero"] = {"hands": "hero_gloves"}
	game.items.append("shop:time_keeper_watch")
	game.equipment_changed.emit()
	await _frames(1)
	var w := _piece(p, "watch")
	check(w != null and w.find_children("*", "MeshInstance3D", true, false).size() > 5,
		"with gloves on and the Time Keeper owned, the Time Keeper's on their wrist")
	game.outfits["hero"] = {}
	game.items.clear()
	game.equipment_changed.emit()
	await _frames(1)
	check(_piece(p, "watch") == null and _piece(p, "tail") != null, "no watch before they have one (the rest still on)")
	game.items.append("shop:shift_watch")

	# --- Home to Earth ---
	game.next_spawn = "HomeSpawn"
	change_scene_to_file(EARTH)
	await _frames(6)
	p = current_scene.find_child("Player", true, false) as Node3D
	check(_pieces(p).is_empty() and not _eyes_glow(p), "back on Earth, the Void look is gone")

	# --- The creator's Void tab, on Earth ---
	creator.open()
	await _frames(2)
	check("Void" in creator.tabs(), "once they've been, the creator has a Void tab")
	check(_pieces(p).is_empty(), "on another tab, the turntable hero looks as on Earth")
	creator._tab = "Void"
	creator._fill()
	await _frames(2)
	check(creator.previewing_void() and _eyes_glow(p) and _piece(p, "tail") != null, "the Void tab shows off their Void look, even on Earth")
	var horns := creator._content.find_child("Void horns", true, false) as Button
	check(horns != null, "the Void tab has a button for each feature")
	if horns:
		horns.pressed.emit()
	await _frames(2)
	check(game.hero.void_feature == "horns" and _piece(p, "horns") != null and _piece(p, "tail") == null, "picking Little horns puts horns on")
	var glow := creator._content.find_child("Glow 2", true, false) as Button
	if glow:
		glow.pressed.emit()
	await _frames(2)
	check(int(game.hero.void_glow) == 2, "picking a glow colour")
	creator.surprise()
	await _frames(2)
	check(VOID_LOOK.has_look(game.hero) and game.hero.name == "Sam", "Surprise me keeps a Void look (and their name)")
	creator.set_value("void_feature", "ears")
	creator.start_over()
	await _frames(2)
	check(game.hero.get("void_feature", "") == "ears", "Start over keeps their Void look")
	creator._tab = "Body"
	creator._fill()
	await _frames(2)
	check(_pieces(p).is_empty(), "off the Void tab it comes off again")
	creator._tab = "Void"
	creator._fill()
	await _frames(2)
	creator.close()
	await _frames(2)
	check(not creator.is_open() and _pieces(p).is_empty() and not _eyes_glow(p), "closing the creator on Earth takes the preview off")

	# --- Race circuits (a stand-in with the circuit's id, like scripts/race_circuit.gd's) ---
	var stand_in := GDScript.new()
	stand_in.source_code = "extends Node3D\nvar circuit_id := \"\"\n"
	stand_in.reload()
	for id in ["lake_loop", "pumpkin_run"]:
		var scene := Node3D.new()
		scene.set_script(stand_in)
		scene.set("circuit_id", id)
		scene.scene_file_path = "res://scenes/races/%s.tscn" % id
		var probe := Node.new()
		scene.add_child(probe)
		root.add_child(scene)
		check(VOID_LOOK.in_void(probe) == (id == "lake_loop"), "%s counts as %s" % [id, "the Void" if id == "lake_loop" else "Earth"])
		scene.free()

	# --- Saving ---
	game.hero["void_feature"] = "antennae"
	game.hero["void_glow"] = 4
	var data := JSON.parse_string(JSON.stringify(game.hero)) as Dictionary
	check(str(data.get("void_feature")) == "antennae" and VOID_LOOK.glow(data) == VOID_LOOK.GLOWS[4], "the Void look saves with the hero")
	check(VOID_LOOK.feature({"void_feature": "wings"}) == VOID_LOOK.FEATURES[0] and not VOID_LOOK.has_look({}),
		"an odd or missing feature falls back safely")
	_end()


func _pieces(p: Node3D) -> Array:
	var model := p.get("model") as Node3D
	return model.find_children(VOID_LOOK.HOLDER + "*", "BoneAttachment3D", true, false)


func _piece(p: Node3D, what: String) -> BoneAttachment3D:
	for n in _pieces(p):
		if n.name == VOID_LOOK.HOLDER + " " + what:
			return n
	return null


func _eyes_glow(p: Node3D) -> bool:
	var glows := [false]
	Clothes._each_surface(p.get("model"), ["Iris"], func(mesh: MeshInstance3D, i: int, _k: int) -> void:
		var m := mesh.get_surface_override_material(i) as StandardMaterial3D
		if m and m.emission_enabled:
			glows[0] = true)
	return glows[0]


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _end() -> void:
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	_finish()


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit(1 if failures > 0 else 0)

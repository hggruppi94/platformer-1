extends SceneTree

# Checks the quick outfit wheel (scripts/quick_outfits.gd, plan item 16): the wardrobe saves outfits into its six
# places; holding Outfit wheel (C, L3) opens the wheel and slows the game, pointing picks one and letting go changes
# into it with a sparkle puff; a tap, a talk or a menu doesn't; skins (scripts/skins.gd) are earned from requests,
# watches and races, picked in the wardrobe and kept by saved outfits; changing works on every body; only owned
# clothes go on; saved outfits and skins survive saving, and old saves (with none) load fine.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_quick_outfits.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.quick_outfits_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.quick_outfits_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"


var failures := 0
var game: Node
var qo: Node
var shop: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var settings := root.get_node("Settings")
	game = root.get_node("Game")
	qo = root.get_node("QuickOutfits")
	shop = root.get_node("Shop")
	settings.use_layout("classic")
	settings.tips = false
	game._resume = {}
	game.pending_message = ""
	game.needs_creator = false
	game.items.clear()
	game.outfits = {"hero": {}}
	game.hero = Hero.blank()
	game.saved_outfits = []
	game.riding = false
	root.get_node("Dialogue").reset()
	root.get_node("Quests").reset()
	root.get_node("Requests").reset()
	root.get_node("Races").reset()
	root.get_node("Clock").set("pulls_home", false)

	# --- The button ---
	check(settings.bindings.get("outfit_wheel") == KEY_C and settings.pad_bindings.get("outfit_wheel") == JOY_BUTTON_LEFT_STICK,
		"Outfit wheel is C and L3 (Settings > Controls)")
	var clash := []
	for group in settings.PAD_GROUPS:
		for a in group:
			if a != "outfit_wheel" and settings.pad_bindings.get(a, -1) == JOY_BUTTON_LEFT_STICK:
				clash.append(a)
	for a in settings.bindings:
		if a != "outfit_wheel" and settings.bindings[a] == KEY_C:
			clash.append(a)
	check(clash.is_empty(), "...and nothing else is on them (%s)" % str(clash))

	# --- Old and odd saves ---
	var empty: Array = SavedOutfits.clean(null)
	check(empty.size() == 6 and empty.all(func(o) -> bool: return o == null), "a save from before the wheel has six empty places")
	var odd: Array = SavedOutfits.clean([{"outfit": {"head": "sk8_beanie", "wings": "x"}, "colors": {"fur": 3.0}}, 5, null, {}, {}, {}, {}, {}])
	check(odd.size() == 6 and odd[0].outfit == {"head": "sk8_beanie"} and odd[0].colors == {"fur": 3} and odd[1] == null
		and odd[0].name == "Outfit 1", "odd saved outfits are tidied up (unknown slots go, at most six, names filled in)")

	change_scene_to_file(TOWN)
	await _frames(10)
	var p := current_scene.find_child("Player", true, false) as Node3D
	for id in ["sk8_beanie", "super_cape", "galaxy_tee", "moon_boots"]:
		game.items.append("shop:" + id)
	await _frames(3)

	# --- The wardrobe ---
	shop.open("Wardrobe")
	await _frames(4)
	shop.wear("sk8_beanie", "head", "hero")
	shop.wear("super_cape", "back", "hero")
	await _frames(2)
	var save_b := shop._panel.find_child("Button save outfit", true, false) as Button
	var forget_b := shop._panel.find_child("Button forget outfit", true, false) as Button
	check(save_b != null and forget_b != null and forget_b.disabled, "the wardrobe has Save this outfit (and Forget it, off for an empty place)")
	check(shop._panel.find_child("Outfit Tip", true, false) != null, "...and says which button opens the wheel")
	var skin_b := shop._panel.find_child("Button skin 1", true, false) as Button
	check(skin_b != null and skin_b.disabled, "no skins earned yet: the skin arrows are off")
	save_b.pressed.emit()
	await _frames(2)
	check(qo.get_slot(0) != null and qo.get_slot(0).outfit == {"head": "sk8_beanie", "back": "super_cape"}, "Save this outfit saves what they've got on into outfit 1")
	(shop._panel.find_child("Button saved 1", true, false) as Button).pressed.emit()
	await _frames(2)
	check(shop.outfit_slot == 1, "the arrows pick the next place")
	shop.wear("", "head", "hero")
	shop.wear("", "back", "hero")
	shop.wear("galaxy_tee", "top", "hero")
	shop.wear("moon_boots", "feet", "hero")

	# --- Skins ---
	root.get_node("Requests").turned_in = 3
	root.get_node("Races").raced = 1
	var got: Array = qo.check_skins()
	check(got.has("starlight") and got.has("checkered") and not got.has("comet"), "3 requests and a race earn Starlight and Checkered Flag (%s)" % str(got))
	check(game.has_item("skin:starlight") and qo.check_skins().is_empty(), "...kept as items, and given only once")
	shop._fill()
	await _frames(2)
	(shop._panel.find_child("Button skin 1", true, false) as Button).pressed.emit()
	await _frames(2)
	check(str(game.hero.get("skin", "")) == "starlight", "the wardrobe's skin arrows put Starlight on")
	(shop._panel.find_child("Button save outfit", true, false) as Button).pressed.emit()
	await _frames(2)
	check(qo.get_slot(1).skin == "starlight" and qo.get_slot(1).outfit.has("top"), "outfit 2 keeps the skin and the tee")
	shop.close()
	await _frames(3)

	# --- The wheel ---
	qo.wear(0)
	await _frames(2)
	Input.action_press("outfit_wheel")
	await _frames(2)
	await create_timer(0.08, true, false, true).timeout
	Input.action_release("outfit_wheel")
	await _frames(3)
	check(not qo.wheel.open and str(game.hero.get("skin", "")) == "", "a quick tap doesn't open the wheel or change anything")
	var puffs: int = qo.puffs
	Input.action_press("outfit_wheel")
	await create_timer(0.35, true, false, true).timeout
	await _frames(2)
	check(qo.wheel.open, "holding Outfit wheel opens the wheel")
	check(is_equal_approx(Engine.time_scale, qo.SLOW), "...and slows the game right down")
	qo.point(qo.slot_angle(1))
	check(qo.wheel.hover == 1, "pointing at outfit 2 picks it")
	qo.point(qo.slot_angle(4))
	check(qo.wheel.hover != 4, "an empty place can't be picked")
	qo.point(qo.slot_angle(1))
	Input.action_release("outfit_wheel")
	await _frames(3)
	check(not qo.wheel.open and is_equal_approx(Engine.time_scale, settings.game_speed), "letting go closes it and the game's back to speed")
	check(game.outfits.hero == {"top": "galaxy_tee", "feet": "moon_boots"} and game.hero.get("skin") == "starlight",
		"...and changes into outfit 2 (%s)" % str(game.outfits.hero))
	check(qo.puffs == puffs + 1 and current_scene.find_child("Outfit Puff", true, false) != null, "...with a puff of sparkles")
	await _frames(2)

	# Not in a menu or a talk
	shop.open("Market")
	await _frames(3)
	Input.action_press("outfit_wheel")
	await create_timer(0.35, true, false, true).timeout
	await _frames(2)
	check(not qo.wheel.open, "it doesn't open in a shop")
	Input.action_release("outfit_wheel")
	shop.close()
	await _frames(3)
	var talker := Node3D.new()
	var talk_script := GDScript.new()
	talk_script.source_code = "extends Node3D\nfunc begin_talk() -> void:\n\tpass\nfunc end_talk() -> void:\n\tpass\n"
	talk_script.reload()
	talker.set_script(talk_script)
	talker.name = "Test Talker"
	current_scene.add_child(talker)
	talker.global_position = p.global_position + Vector3(1.5, 0, 0)
	root.get_node("Dialogue").say(talker, "Test", ["Hello!", "Again!"])
	await _frames(2)
	Input.action_press("outfit_wheel")
	await create_timer(0.35, true, false, true).timeout
	await _frames(2)
	check(not qo.wheel.open, "...or in a talk")
	Input.action_release("outfit_wheel")
	await _frames(2)
	root.get_node("Dialogue").end()
	talker.queue_free()
	await _frames(3)
	check(not root.get_node("Dialogue").is_active(), "(the talk's over)")

	# Only owned clothes go on
	qo.slots()[2] = {"name": "Borrowed", "outfit": {"head": "sk8_beanie", "face": "heart_shades"}, "colors": {}, "skin": "comet"}
	qo.wear(2)
	check(game.outfits.hero == {"head": "sk8_beanie"} and not game.hero.has("skin"), "things not owned (and skins not earned) are left off")

	# --- Every body ---
	var bodies: Array = Hero.BODY_ORDER.duplicate()
	bodies.append_array(Hero.SECRET_ORDER)
	var bad := []
	for body in bodies:
		game.hero.body = body
		p.set_rider("hero", false)
		qo.wear(0)
		await _frames(2)
		var model := p.get("model") as Node3D
		if not _has_piece(model, "head") or not _has_piece(model, "back"):
			bad.append("%s: beanie and cape" % body)
		qo.wear(1)
		await _frames(2)
		model = p.get("model") as Node3D
		if _has_piece(model, "head") or _has_piece(model, "back") or game.outfits.hero.get("top") != "galaxy_tee":
			bad.append("%s: tee, no hat" % body)
		var want: Color = Hero.SWATCHES[Skins.SKINS.starlight.colors.fur - 1]
		var fur := _fur_colour(model, body)
		if body in Skins.KEEP:
			if fur.is_equal_approx(want):
				bad.append("%s: kept their own skin tone" % body)
		elif not fur.is_equal_approx(want):
			bad.append("%s: Starlight fur (%s)" % [body, str(fur)])
	check(bad.is_empty(), "changing outfits works on every body (%d), skins too, and Earth kids keep their skin tone %s" % [bodies.size(), str(bad)])
	game.hero.body = "hippo"
	p.set_rider("hero", false)

	# --- The creator ---
	game.hero["skin"] = "starlight"
	root.get_node("Creator").set_color("fur", 3)
	check(not game.hero.has("skin") and game.hero.colors.fur == 3, "picking a fur colour in the creator takes the skin off, so it shows")
	root.get_node("Creator").set_color("fur", 0)

	# --- Saving ---
	qo.wear(1)
	game.save_game()
	game.saved_outfits = []
	game.hero = Hero.blank()
	game.load_game()
	check(qo.count() == 3 and qo.get_slot(1).skin == "starlight" and str(game.hero.get("skin", "")) == "starlight",
		"saved outfits and the skin come back from the save")
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	data.erase("saved_outfits")
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	game.load_game()
	check(game.saved_outfits.size() == 6 and qo.count() == 0, "an old save (no saved outfits) loads with six empty places")
	Input.action_press("outfit_wheel")
	await create_timer(0.35, true, false, true).timeout
	await _frames(2)
	check(not qo.wheel.open and qo.get("_hinted"), "with nothing saved, holding it says how to save one instead")
	Input.action_release("outfit_wheel")
	await _frames(2)
	_finish()


func _has_piece(model: Node3D, slot: String) -> bool:
	for n in model.find_children("Clothes %s *" % slot, "", true, false):
		if not n.is_queued_for_deletion():
			return true
	return false


func _fur_colour(model: Node3D, body: String) -> Color:
	var who: String = Hero.BODIES[body].char
	var names: Array = Clothes.OWN_LOOKS.get(who, {}).get("fur", [])
	var out := [Color.BLACK]
	if names.is_empty():
		return Color.BLACK
	Clothes._each_surface(model, [names[0]], func(mesh: MeshInstance3D, i: int, _k: int) -> void:
		var m := mesh.get_surface_override_material(i) as StandardMaterial3D
		if m == null:
			m = mesh.mesh.surface_get_material(i) as StandardMaterial3D
		if m:
			out[0] = m.albedo_color)
	return out[0]


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _finish() -> void:
	Engine.time_scale = 1.0
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	else:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	else:
		DirAccess.remove_absolute(SETTINGS)
	print("RESULT %s (%d failed)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)

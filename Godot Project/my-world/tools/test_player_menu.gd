extends SceneTree

# Checks the player menu (scripts/player_menu.gd): Tab and Back open it on Quests, Q / E and LB / RB go from sheet to
# sheet, the old keys (Q for the quest log, M for the map) open it on their own sheet and close it again there, Tab,
# Pause and B close it, and it stays shut in a conversation, the character creator and the wardrobe. Every sheet
# builds, the Hero sheet opens the wardrobe, the Save sheet saves, and the Settings sheet is the pause menu's settings
# with the Player menu key and button in Controls, which can be changed. Old settings with the quest log on Tab give
# Tab to the player menu.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_player_menu.gd
#
# Your own save and settings are put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0
var game: Node
var settings: Node
var dialogue: Node
var quests: Node
var map: Node
var menu: Node
var pause_menu: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(200.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	settings = root.get_node("Settings")
	dialogue = root.get_node("Dialogue")
	quests = root.get_node("Quests")
	map = root.get_node("TownMap")
	menu = root.get_node("PlayerMenu")
	pause_menu = root.get_node("PauseMenu")
	settings.use_layout("classic")
	settings.last_device = "keyboard"
	game._resume = {}
	game.pending_message = ""
	dialogue.reset()
	quests.reset()
	game.hero["name"] = "Testy"

	# The key and button, in the remapping lists
	check(settings.REBINDABLE.any(func(p: Array) -> bool: return p[0] == "player_menu") and settings.key_name("player_menu") == "Tab",
		"the player menu key is rebindable, on %s" % settings.key_name("player_menu"))
	check(settings.PAD_REBINDABLE.any(func(p: Array) -> bool: return p[0] == "player_menu") and settings.pad_name("player_menu") == "Back",
		"...and its controller button too, on %s" % settings.pad_name("player_menu"))
	check(settings.PAD_GROUPS.all(func(g: Array) -> bool: return "player_menu" in g), "the button can't clash with others in use at the same time")

	change_scene_to_file(TOWN)
	await _frames(6)

	# Tab opens it on Quests, paused; Tab closes it
	_press("player_menu")
	await _frames(2)
	check(menu.is_open() and menu.sheet == "quests" and paused, "Tab opens the menu on Quests (game paused)")
	check(quests.is_log_open() and menu._body.find_child("*", true, false) != null, "the Quests sheet shows the quest log")
	_press("player_menu")
	await _frames(2)
	check(not menu.is_open() and not paused, "...and Tab closes it")
	_key(KEY_TAB)
	await _frames(2)
	check(menu.is_open(), "the real Tab key opens it too")

	# E / RB go along the sheets, Q / LB back; every sheet builds something
	var seen := []
	for i in menu.SHEETS.size():
		seen.append(menu.sheet)
		check(menu._body.get_child_count() > 0, "the %s sheet has something on it" % menu.sheet)
		_press("menu_next")
		await _frames(2)
	check(seen == menu.SHEETS.map(func(p: Array) -> String: return p[0]), "E goes through every sheet in order: %s" % [seen])
	check(menu.sheet == "save", "...and stops at the last one")
	_press("menu_prev")
	await _frames(2)
	check(menu.sheet == "settings", "Q goes back one")
	menu.show_sheet("map")
	await _frames(2)
	check(map.is_open(), "the Map sheet shows the town map")
	_key(KEY_Q)
	await _frames(2)
	check(menu.sheet == "goals" and menu.is_open(), "Q on the Map sheet goes back to Goals")
	_key(KEY_Q)
	await _frames(2)
	check(menu.sheet == "quests" and menu.is_open(), "...and again to Quests")
	_key(KEY_Q)
	await _frames(2)
	check(not menu.is_open() and not paused, "Q on Quests closes it, like the old quest log")

	# The old keys: M opens it on the Map, M again closes it; Q opens it on Quests and M jumps to the map
	_press("map")
	await _frames(2)
	check(menu.is_open() and menu.sheet == "map" and map.is_open() and paused, "M opens the menu on the Map sheet")
	_press("map")
	await _frames(2)
	check(not menu.is_open() and not paused, "...and M again closes it")
	_key(KEY_Q)
	await _frames(2)
	check(menu.is_open() and menu.sheet == "quests", "Q opens it on Quests")
	_key(KEY_M)
	await _frames(2)
	check(menu.sheet == "map", "M on another sheet goes to the Map")
	_press("pause")
	await _frames(2)
	check(not menu.is_open() and not paused and not pause_menu.is_open(), "Pause closes it (not opening the pause menu)")

	# Controller: Back opens it, LB / RB along the sheets, B closes it
	_pad(JOY_BUTTON_BACK)
	await _frames(2)
	check(menu.is_open() and menu.sheet == "quests", "Back on a controller opens it on Quests")
	_pad(JOY_BUTTON_RIGHT_SHOULDER)
	await _frames(2)
	check(menu.sheet == "goals", "RB goes to the next sheet (Goals)")
	_pad(JOY_BUTTON_LEFT_SHOULDER)
	await _frames(2)
	check(menu.sheet == "quests" and menu.is_open(), "LB goes back (and doesn't close it on Quests)")
	_pad(JOY_BUTTON_LEFT_SHOULDER)
	await _frames(2)
	check(menu.sheet == "quests" and menu.is_open(), "...LB on Quests stays put")
	_pad(JOY_BUTTON_B)
	await _frames(2)
	check(not menu.is_open() and not paused, "B closes it")
	check(settings.prompt("player_menu") == "Back" and settings.prompt("quest_log") == "Back", "on a controller, prompts say Back for the menu and the quest log")
	menu.open("quests")
	await _frames(1)
	check(menu._hint.text.contains("LB / RB") and menu._prev_hint.text.contains("LB"), "the menu's hints say LB / RB on a controller: \"%s\"" % menu._hint.text)
	menu.close()
	settings.last_device = "keyboard"

	# Not in a conversation, the character creator or the wardrobe
	dialogue.talk_to(current_scene.find_children("Talk", "Area3D", true, false)[0])
	await _frames(2)
	_press("player_menu")
	_press("map")
	await _frames(2)
	check(not menu.is_open(), "it stays shut in a conversation")
	dialogue.end()
	await _frames(2)
	root.get_node("Creator").open()
	await _frames(2)
	_press("player_menu")
	await _frames(2)
	check(not menu.is_open(), "...and in the character creator")
	root.get_node("Creator").close()
	await _frames(2)

	# The Hero sheet opens the wardrobe (the menu steps aside)
	menu.open("hero")
	await _frames(2)
	var wardrobe := menu._body.find_child("Wardrobe", true, false) as Button
	check(wardrobe != null and menu._body.find_child("Change hero", true, false) != null, "the Hero sheet has the wardrobe and Change your hero...")
	wardrobe.pressed.emit()
	await _frames(2)
	var shop := root.get_node("Shop")
	check(not menu.is_open() and shop.is_open() and shop._stall == "Wardrobe" and paused, "the wardrobe button opens the wardrobe")
	_press("player_menu")
	await _frames(2)
	check(not menu.is_open() and shop.is_open(), "...and the menu stays shut over it")
	shop.close()
	await _frames(2)

	# The Bag sheet: sparkles and things
	game.sparkles = 12
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	menu.open("bag")
	await _frames(2)
	var wallet := menu._body.find_child("Sparkles", true, false) as Label
	var things := menu._body.find_child("Things", true, false) as Label
	check(wallet != null and wallet.text.contains("12"), "the Bag shows the sparkles: %s" % (wallet.text if wallet else "?"))
	check(things != null and things.text.contains("Skateboard"), "...and the skateboard")

	# The Skate sheet: the lesson and the tips
	menu.show_sheet("skate")
	await _frames(2)
	check(menu._body.find_child("Lesson", true, false) != null and menu._body.find_child("Tips", true, false) != null,
		"the Skate sheet has the skate lesson and the how-to tips")

	# The Save sheet saves
	menu.show_sheet("save")
	await _frames(2)
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	(menu._body.find_child("Save now", true, false) as Button).pressed.emit()
	await _frames(2)
	check(FileAccess.file_exists(SAVE) and menu._note.text.contains("Saved"), "Save now saves the game")
	(menu._body.find_child("New game", true, false) as Button).pressed.emit()
	await _frames(2)
	check(menu._body.find_child("Keep playing", true, false) != null, "New game asks first")
	(menu._body.find_child("Keep playing", true, false) as Button).pressed.emit()
	await _frames(2)
	check(menu.is_open() and menu.sheet == "save", "...and No keeps playing")

	# The Settings sheet: the pause menu's tabs, with the Player menu key in Controls
	menu.show_sheet("settings")
	await _frames(2)
	var tabs := menu._body.find_child("SettingsTabs", true, false) as TabContainer
	check(tabs != null and tabs.get_tab_count() == 5, "the Settings sheet has the settings tabs")
	var labels: Array = tabs.find_children("*", "Label", true, false) if tabs else []
	check(labels.any(func(l: Label) -> bool: return l.text == "Player menu"), "Controls lists the Player menu")
	var pad_button := tabs.find_child("Pad player_menu", true, false) as Button if tabs else null
	check(pad_button != null and pad_button.text.contains("Back"), "...on Back on a controller (%s)" % (pad_button.text if pad_button else "?"))

	# Changing the key right there: I instead of Tab
	var key_button: Button = null
	for l in labels:
		if l.text == "Player menu":
			key_button = l.get_parent().get_child(l.get_index() + 1).get_child(0) as Button
	check(key_button != null and key_button.text == "Tab", "the Player menu key shows Tab")
	pause_menu._start_rebind("player_menu", key_button)
	_key(KEY_I)
	await _frames(3)
	check(settings.key_name("player_menu") == "I" and menu.is_open() and menu.sheet == "settings", "pressing I sets it (the menu stays open)")
	var rebuilt := menu._body.find_child("SettingsTabs", true, false) as TabContainer
	check(rebuilt != null and rebuilt.find_children("*", "Button", true, false).any(func(b: Button) -> bool: return b.text == "I"),
		"the sheet shows the new key")
	_key(KEY_I)
	await _frames(2)
	check(not menu.is_open(), "I closes the menu now")
	_key(KEY_TAB)
	await _frames(2)
	check(not menu.is_open(), "...and Tab doesn't open it any more")
	_key(KEY_I)
	await _frames(2)
	check(menu.is_open(), "...I opens it")
	menu.close()
	settings.rebind("player_menu", KEY_TAB)
	check(settings.key_name("player_menu") == "Tab", "and back to Tab")

	# Old settings, from before the player menu, with the quest log on Tab: Tab goes to the player menu
	var cf := ConfigFile.new()
	for a in settings.default_bindings():
		if a != "player_menu":
			cf.set_value("keys", a, settings.default_bindings()[a])
	cf.set_value("keys", "quest_log", KEY_TAB)
	cf.set_value("keys", "skate_grind", KEY_Q)
	for a in settings.default_pad_bindings():
		if a != "player_menu":
			cf.set_value("pad", a, settings.default_pad_bindings()[a])
	cf.set_value("pad", "quest_log", JOY_BUTTON_BACK)
	cf.save(SETTINGS)
	settings.load_settings()
	settings.apply()
	check(settings.key_name("player_menu") == "Tab" and settings.bindings["quest_log"] == 0, "old settings: Tab is the player menu, the quest log has no key (Q's taken)")
	check(settings.pad_name("player_menu") == "Back" and settings.pad_bindings["quest_log"] == -1, "...and Back is the player menu's button")
	check(settings.prompt("quest_log") == "Tab", "...and the quest log's prompt says Tab")
	settings.use_layout("classic")

	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	_finish()


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	quit(failures)


func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	var up := InputEventAction.new()
	up.action = action
	Input.parse_input_event(up)


func _key(code: int) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code as Key
	e.pressed = true
	Input.parse_input_event(e)
	var up := InputEventKey.new()
	up.physical_keycode = code as Key
	Input.parse_input_event(up)


func _pad(button: int) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button as JoyButton
	e.pressed = true
	Input.parse_input_event(e)
	var up := InputEventJoypadButton.new()
	up.button_index = button as JoyButton
	Input.parse_input_event(up)


func _frames(n: int) -> void:
	for i in n:
		await process_frame

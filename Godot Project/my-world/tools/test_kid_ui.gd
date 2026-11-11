extends SceneTree

# Checks the kid-friendly UI pass (Hayden's 7 Nov 2026 playtest):
#   - talking text: laid out first, then revealed (no sliding or jumping words), a Talking speed setting (All at once
#     shows the line straight away) and Comic capitals on or off
#   - a smaller HUD (Settings.hud_size, Small by default) that the minimap follows too
#   - the "To do" list under the stats: a quest's checklist, or the sentence of its step that says what to do
#   - the player menu's picture tabs, the sentence about each sheet, the key chips and the round X, and the menu tour
#     (every sheet in turn, Q / E step through it, closing ends it, and it's remembered)
#   - the pause menu's pictures and its "Show me the menu"
#   - sprinting: hold the roll button
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_kid_ui.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.kid_ui_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.kid_ui_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var settings := root.get_node("Settings")
	var game := root.get_node("Game")
	var dialogue := root.get_node("Dialogue")
	var quests := root.get_node("Quests")
	var menu := root.get_node("PlayerMenu")
	settings.use_layout("classic")
	settings.last_device = "keyboard"
	settings.tips = false
	game._resume = {}
	game.pending_message = ""
	game.needs_creator = false
	dialogue.reset()
	quests.reset()
	root.get_node("Clock").set("pulls_home", false)
	root.size = Vector2i(1280, 720)

	# --- Settings ---
	var fresh: Node = load("res://scripts/settings.gd").new()
	check(is_equal_approx(fresh.hud_size, 0.8) and fresh.talk_speed > 0.0 and fresh.talk_caps and fresh.objectives,
		"new settings: Small HUD, words typed out, comic capitals, to-do list on")
	fresh.free()
	check(settings.hud(20) == roundi(20 * settings.text_scale * settings.hud_size), "Settings.hud() is text size times HUD size")

	# --- Icons ---
	var all_ok := true
	for kind in UiIcons.kinds():
		var tex := UiIcons.get_icon(kind)
		all_ok = all_ok and tex != null and tex.get_width() == UiIcons.SIZE
	check(all_ok, "every menu picture draws (%d of them)" % UiIcons.kinds().size())
	check(UiIcons.get_icon("map") == UiIcons.get_icon("map"), "...and is only drawn once")

	# --- Short goals for the to-do list ---
	check(quests.short_goal({"text": "Find the other Nina at Willow Pond."}) == "Find the other Nina at Willow Pond.", "a short step is the goal as it is")
	check(quests.short_goal({"text": "Rex is writing the Doggie Bill of Rights. Help him pick the most important right."}) == "Help him pick the most important right.",
		"a long step: the sentence that says what to do")
	check(quests.short_goal({"text": "anything", "goal": "Pop the Gloop King"}) == "Pop the Gloop King", "a step's own \"goal\" wins")

	change_scene_to_file(TOWN)
	await _frames(10)
	var hud: Node = current_scene.find_children("*", "CanvasLayer", true, false).filter(func(n: Node) -> bool: return n.has_method("todo_items")).front() \
		if current_scene.find_children("*", "CanvasLayer", true, false).any(func(n: Node) -> bool: return n.has_method("todo_items")) else null
	check(hud != null, "the town has the HUD")
	var player := current_scene.find_child("Player", true, false) as CharacterBody3D

	# --- Smaller HUD ---
	if hud:
		check(hud.stats_label.get_theme_font_size("font_size") == settings.hud(20), "the stats are HUD-sized (%d px)" % hud.stats_label.get_theme_font_size("font_size"))
		check(hud.hp_bar != null and hud.xp_bar != null, "HP and XP are bars")
		check(not hud.todo.visible, "no quests: no to-do list")
	var map := root.get_node("TownMap")
	await _frames(2)
	check(is_equal_approx(map._mini_layer.scale.x, settings.hud_size), "the minimap is HUD-sized too")

	# --- The to-do list ---
	dialogue.flags["bramble_flowers_start"] = true
	quests.check()
	await _frames(25)
	if hud:
		var items: Array = hud.todo_items()
		check(hud.todo.visible and hud.todo_title.text.contains("Flowers"), "a quest starts: the to-do list shows it (%s)" % hud.todo_title.text)
		check(items.size() == quests.checklist("bramble_flowers").size() and items.size() > 1, "...with its checklist (%d things)" % items.size())
		dialogue.flags["rex_campaign_start"] = true
		quests.check()
		await _frames(25)
		check(hud.todo_title.text.contains("Flowers"), "a newer quest doesn't steal the list: still the followed one (%s)" % hud.todo_title.text)
		quests.follow("rex_campaign", true)
		await _frames(25)
		check(hud.todo_items().size() > items.size(), "following the newer one too: both on the list (%d)" % hud.todo_items().size())
		quests.follow_only("rex_campaign")
		await _frames(25)
		check(hud.todo_title.text.contains("Rex"), "follow just the newer one: the list switches (%s)" % hud.todo_title.text)
		settings.objectives = false
		await _frames(25)
		check(not hud.todo.visible, "To-do list off in Settings: hidden")
		settings.objectives = true
		await _frames(25)
		check(hud.todo.visible, "...and back on")

	# --- Talking text ---
	var talker_script := GDScript.new()
	talker_script.source_code = "extends Node3D\nfunc begin_talk() -> void:\n\tpass\nfunc end_talk() -> void:\n\tpass\n"
	talker_script.reload()
	var talker := Node3D.new()
	talker.set_script(talker_script)
	current_scene.add_child(talker)
	check(dialogue._text.visible_characters_behavior == TextServer.VC_CHARS_AFTER_SHAPING,
		"talking text is laid out first, then revealed (letters type out in their places)")
	dialogue.say(talker, "Bramble", ["Hello there, could you help me fill the window boxes with flowers please?"])
	await _frames(3)
	check(dialogue.is_typing() and dialogue.shown_characters() < dialogue.current_line().length(), "the words type out")
	check(dialogue._panel.scale == Vector2.ONE, "no squashy bounce on the banner")
	dialogue.end()
	await _frames(12)
	settings.talk_speed = 0.0
	dialogue.say(talker, "Bramble", ["All at once, please."])
	await _frames(2)
	check(not dialogue.is_typing(), "Talking speed \"All at once\": the whole line straight away")
	dialogue.end()
	await _frames(12)
	settings.talk_speed = 40.0
	settings.set_value("talk_caps", false)
	check(not dialogue._text.uppercase, "Comic capitals off: ordinary letters")
	settings.set_value("talk_caps", true)
	check(dialogue._text.uppercase, "...and back on")

	# --- The player menu ---
	menu.open("quests")
	await _frames(3)
	var icons := true
	for b in menu._tab_buttons.values():
		icons = icons and (b as Button).icon != null
	check(icons, "every tab has a picture")
	check(menu._about.text == menu.ABOUT["quests"], "a sentence says what's on the sheet: \"%s\"" % menu._about.text)
	check(menu._hint_row.get_child_count() == 3, "key chips along the bottom (change page, pick, close)")
	var vr := Rect2(Vector2.ZERO, Vector2(root.size))
	var on_screen := vr.grow(1.0).encloses(menu._close.get_global_rect())
	for b in menu._tab_buttons.values():
		on_screen = on_screen and vr.grow(1.0).encloses((b as Control).get_global_rect())
	check(on_screen, "the tabs and the round X fit on a 1280x720 screen")
	menu._close.pressed.emit()
	await _frames(2)
	check(not menu.is_open(), "the round X closes the menu")

	# --- The menu tour ---
	dialogue.flags.erase("tour_menu")
	menu.start_tour()
	await _frames(3)
	check(menu.is_open() and menu.touring(), "\"Show me the menu\" opens the menu and starts the tour")
	var seen: Array = [menu.sheet]
	for i in menu.SHEETS.size():
		menu.tour.step(1)
		await _frames(2)
		if not seen.has(menu.sheet):
			seen.append(menu.sheet)
	check(seen.size() == menu.SHEETS.size(), "the tour goes through every sheet (%s)" % ", ".join(seen))
	var bubble: Control = menu.tour._bubble
	check(vr.grow(1.0).encloses(bubble.get_global_rect()), "...its bubble stays on the screen")
	var ev := InputEventAction.new()
	ev.action = "menu_prev"
	ev.pressed = true
	var at: int = menu.tour.index
	Input.parse_input_event(ev)
	await _frames(3)
	check(menu.tour.index == at - 1, "Q goes back a step in the tour")
	menu.tour.go(menu.tour.steps.size() - 1)
	await _frames(2)
	check(menu.tour._next.text == "Done!", "the last step says Done!")
	menu.tour._next.pressed.emit()
	await _frames(2)
	check(not menu.touring() and menu.is_open() and dialogue.flags.has("tour_menu"), "Done ends the tour, leaves the menu open, and it's remembered")
	menu.close()
	dialogue.flags.erase("tour_menu")
	menu.start_tour()
	await _frames(2)
	menu.close()
	await _frames(2)
	check(not menu.touring() and not menu.is_open() and dialogue.flags.has("tour_menu"), "closing the menu mid-tour ends it too")

	# --- The pause menu ---
	var pause := root.get_node("PauseMenu")
	pause.open()
	await _frames(3)
	var buttons: Array = pause.box.find_children("*", "Button", true, false)
	var resume: Button = buttons.filter(func(b: Button) -> bool: return b.text == "Resume").front() if not buttons.is_empty() else null
	check(resume != null and resume.icon != null, "the pause menu's Resume has a picture")
	check(buttons.any(func(b: Button) -> bool: return b.text == "Show me the menu"), "...and there's \"Show me the menu\"")
	pause.close()
	await _frames(3)

	# --- Sprinting: on a big flat floor up in the sky, out of everything's way ---
	if player:
		var floor := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		(shape.shape as BoxShape3D).size = Vector3(400, 1, 400)
		floor.add_child(shape)
		current_scene.add_child(floor)
		floor.global_position = Vector3(0, 299.5, 0)
		player.global_position = Vector3(0, 301.0, 0)
		player.velocity = Vector3.ZERO
		await _frames(20)
		Input.action_press("move_back")
		await _frames(15)
		Input.action_press("dash")
		for i in 50:
			await physics_frame
		var v := Vector2(player.velocity.x, player.velocity.z).length()
		check(player.is_sprinting() and v > player.speed * 1.3, "holding the roll button: she rolls, then sprints (%.1f m/s, runs at %.1f)" % [v, player.speed])
		Input.action_release("dash")
		for i in 40:
			await physics_frame
		v = Vector2(player.velocity.x, player.velocity.z).length()
		check(not player.is_sprinting() and v < player.speed * 1.1, "let go: back to a run (%.1f m/s)" % v)
		Input.action_release("move_back")
		var sp: float = game.sp
		Input.action_press("move_back")
		Input.action_press("dash")
		for i in 60:
			await physics_frame
		Input.action_release("dash")
		Input.action_release("move_back")
		check(game.sp >= sp - player.roll_cost - 0.01, "sprinting itself costs no stamina (just the roll at the start)")
	_finish()


func _finish() -> void:
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

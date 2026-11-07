extends SceneTree

# Checks the shared menu look (scripts/ui_style.gd, plan item 15): the theme is the project's theme and has the comic
# lettering, folder tabs and cards; every menu still opens and closes on the keyboard and on a controller (the player
# menu and each of its sheets, the pause menu, a shop and the wardrobe), and nothing in them runs off the screen or
# sits on top of something else at 1280x720 and at 1920x1080; the minimap is on by default (old settings get it
# switched on once, then it stays as the player leaves it), round, with a compass; and quests show as cards and as a
# banner that slides in.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_ui_style.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.ui_style_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.ui_style_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0
var settings: Node
var menu: Node


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
	settings = root.get_node("Settings")
	menu = root.get_node("PlayerMenu")
	var game := root.get_node("Game")
	settings.use_layout("classic")
	settings.last_device = "keyboard"
	settings.tips = false
	game._resume = {}
	game.pending_message = ""
	game.needs_creator = false
	root.get_node("Dialogue").reset()
	root.get_node("Quests").reset()
	root.get_node("Clock").set("pulls_home", false)

	# --- The theme ---
	var t: Theme = UiStyle.theme()
	check(t.default_font and t.default_font.resource_path == UiStyle.FONT_PATH, "the menus are lettered in the subtitles' comic font")
	check(t.is_type_variation("SheetTab", "Button") and t.is_type_variation("Card", "PanelContainer") and t.is_type_variation("SheetPanel", "PanelContainer"),
		"it has folder tabs, sheet pages and cards")
	var n := t.get_stylebox("normal", "Button") as StyleBoxFlat
	var p := t.get_stylebox("hover_pressed", "Button") as StyleBoxFlat
	check(n.border_width_bottom > p.border_width_bottom and p.content_margin_top > n.content_margin_top,
		"buttons have a lip and sink into it when pressed")
	check(t.has_stylebox("focus", "Button") and (t.get_stylebox("focus", "Button") as StyleBoxFlat).border_width_top >= 3,
		"a focused button has a clear ring, for controllers")
	check(ProjectSettings.get_setting("gui/theme/custom", "") == "res://ui/theme.tres" and load("res://ui/theme.tres") is Theme,
		"it's the project's theme (ui/theme.tres), so every menu wears it")
	settings.high_contrast = true
	var hc: Theme = UiStyle.theme()
	check((hc.get_stylebox("focus", "Button") as StyleBoxFlat).border_color == Color(1, 0.9, 0.1), "High contrast keeps its yellow focus ring")
	settings.high_contrast = false

	# --- Minimap on by default, and old settings get it once ---
	var cf := ConfigFile.new()
	cf.set_value("settings", "minimap", false)
	cf.save(SETTINGS)
	settings.load_settings()
	check(settings.minimap, "old settings with the minimap off get it switched on (it's on by default now)")
	settings.save_settings()
	settings.minimap = false
	settings.save_settings()
	settings.load_settings()
	check(not settings.minimap, "...once: switched off again, it stays off")
	settings.minimap = true

	change_scene_to_file(TOWN)
	await _frames(8)
	var map := root.get_node("TownMap")
	check(map._mini_layer.visible, "the minimap shows in town")
	check(map._mini.clip_children == CanvasItem.CLIP_CHILDREN_ONLY and map._mini_frame != null, "...round, with a compass ring round it")

	# --- Every menu, at two screen sizes ---
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = size
		await _frames(3)
		await _menus(size)

	# --- Quest cards and the banner ---
	root.size = Vector2i(1280, 720)
	var quests := root.get_node("Quests")
	root.get_node("Dialogue").flags["rex_campaign_start"] = true
	quests.check()
	await _frames(2)
	check(quests.note_text().contains("Rex for Mayor"), "starting a quest shows the banner")
	var banner: Control = quests._note
	var x0 := banner.position.x
	await _frames(40)
	check(banner.position.x < x0 or settings.reduce_motion, "...sliding in from the right")
	var vr := Rect2(Vector2.ZERO, Vector2(root.size))
	check(vr.encloses(banner.get_global_rect()), "...and it ends up on the screen (%s)" % str(banner.get_global_rect()))
	var cards: Control = quests.cards_view()
	root.add_child(cards)
	var c := cards.get_node_or_null("Card rex_campaign")
	check(c != null and c.theme_type_variation == "Card", "the quest log shows the quest as a card")
	if c:
		var text := ""
		for l in c.find_children("*", "Label", true, false):
			text += (l as Label).text + " | "
		check(text.contains("Rex for Mayor") and text.contains("From Rex"), "...with its name and who gave it (%s)" % text.left(80))
		check(c.find_child("Picture", true, false) is QuestPicture, "...a picture")
		check(c.find_children("Tick*", "Label", true, false).size() >= 3 and text.contains("○"), "...the steps with ticks")
		check(text.contains("Reward:"), "...and the reward")
	cards.free()
	_finish()


func _menus(size: Vector2i) -> void:
	var tag := "%dx%d" % [size.x, size.y]
	# The player menu: keyboard (Tab) and controller (its button), every sheet
	_press("player_menu")
	await _frames(3)
	check(menu.is_open(), "%s: Tab opens the player menu" % tag)
	for pair in menu.SHEETS:
		menu.show_sheet(pair[0])
		await _frames(3)
		_fits(menu.root, "%s: the %s sheet" % [tag, pair[1]])
	_press("player_menu")
	await _frames(3)
	check(not menu.is_open(), "%s: ...and Tab closes it" % tag)
	_pad(int(settings.pad_bindings.get("player_menu", JOY_BUTTON_BACK)))
	await _frames(3)
	check(menu.is_open(), "%s: the controller's button opens it" % tag)
	_pad(JOY_BUTTON_B)
	await _frames(3)
	check(not menu.is_open(), "%s: ...and B closes it" % tag)
	# The pause menu
	var pause := root.get_node("PauseMenu")
	_press("pause")
	await _frames(3)
	check(pause.is_open(), "%s: Pause opens the pause menu" % tag)
	_fits(pause.root if pause.get("root") else pause, "%s: the pause menu" % tag)
	_press("pause")
	await _frames(3)
	check(not pause.is_open(), "%s: ...and closes it" % tag)
	# A shop and the wardrobe
	var shop := root.get_node("Shop")
	for stall in ["Market", "Wardrobe"]:
		shop.open(stall)
		await _frames(8)
		check(shop.is_open(), "%s: the %s opens" % [tag, stall])
		_fits(shop._panel, "%s: the %s" % [tag, stall])
		_pad(JOY_BUTTON_B)
		await _frames(3)
		check(not shop.is_open(), "%s: ...and B closes it" % tag)


func _fits(top: Node, what: String) -> void:
	# Every button and label showing is on the screen (or scrolled out of sight inside its scroll box), and no two
	# buttons side by side sit on top of each other
	var vr := Rect2(Vector2.ZERO, Vector2(root.size)).grow(1.0)
	var off: Array[String] = []
	var overlaps: Array[String] = []
	for ctl in top.find_children("*", "Control", true, false):
		var c := ctl as Control
		if not c.is_visible_in_tree() or not (c is Button or c is Label):
			continue
		var r := c.get_global_rect()
		var clip := _scroll_of(c)
		if clip and not clip.get_global_rect().intersects(r):
			continue
		if not vr.encloses(r) and off.size() < 6:
			off.append("%s %s" % [c.name, str(r)])
	for ctl in top.find_children("*", "Button", true, false):
		var b := ctl as Button
		if not b.is_visible_in_tree():
			continue
		for other in b.get_parent().get_children():
			if other is Button and other != b and (other as Button).is_visible_in_tree() and other.get_index() > b.get_index():
				if b.get_global_rect().grow(-2.0).intersects((other as Button).get_global_rect().grow(-2.0)) and overlaps.size() < 4:
					overlaps.append("%s / %s" % [b.name, other.name])
	check(off.is_empty(), "%s fits on the screen (%s)" % [what, ", ".join(off)])
	check(overlaps.is_empty(), "%s: no buttons on top of each other (%s)" % [what, ", ".join(overlaps)])


func _scroll_of(c: Node) -> ScrollContainer:
	var n := c.get_parent()
	while n:
		if n is ScrollContainer:
			return n
		n = n.get_parent()
	return null


func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	var up := InputEventAction.new()
	up.action = action
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

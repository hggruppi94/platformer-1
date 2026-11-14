extends SceneTree

# Checks that every menu and panel fits on the screen (Hayden, 8 Nov 2026: "zippys mod menu ui is getting cut off. can
# you check all ui to make sure its uniform and fits on screen?"). Opens each screen in turn (every shop stall, Zippy's
# Tune-Up, the wardrobe, every sheet of the player menu, the pause menu, the map, the creator, a conversation with
# choices, a watch card, the quick outfit wheel...) at several window shapes (16:9, 16:10, 4:3, 21:9) and text sizes,
# and lists anything that pokes off the edge of the screen. With an output folder it saves a picture of each too.
# Opens a window (not --headless), on an empty stage, so it needs no models:
#
#   godot --path "Godot Project/my-world" --script res://tools/audit_ui.gd -- [output folder] [--quick]
#
# Exits 1 if anything is cut off. --quick checks 16:9 and 4:3 at Normal and Largest text only.
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.ui_audit_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.ui_audit_backup.cfg"

const WINDOWS := [["16x9", Vector2i(1280, 720)], ["4x3", Vector2i(1024, 768)], ["16x10", Vector2i(1280, 800)],
	["21x9", Vector2i(2560, 1080)]]
const TEXT_SIZES := [["normal", 1.0], ["large", 1.25], ["larger", 1.5], ["largest", 2.0]]
const UI_WATCH := preload("res://tools/ui_watch.gd")

var out_dir := ""
var quick := false
var only_window := ""                      # e.g. --window=4x3: just that shape
var problems: Array[String] = []
var _checked := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--quick":
			quick = true
		elif a.begins_with("--window="):
			only_window = a.trim_prefix("--window=")
		else:
			out_dir = a
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
	create_timer(1800.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _node(n: String) -> Node:
	return root.get_node(n)


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var game := _node("Game")
	game._resume = {}
	game.pending_message = ""
	game.needs_creator = false
	game.sparkles = 240
	_node("Settings").tips = false
	_node("PlayerMenu").auto_tour = false
	# An empty stage with a sky-ish colour behind the menus
	var stage := Node3D.new()
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.36, 0.55, 0.42)
	stage.add_child(env)
	var cam := Camera3D.new()
	stage.add_child(cam)
	root.add_child(stage)
	current_scene = stage
	for i in 6:
		await process_frame
	var windows: Array = WINDOWS.slice(0, 2) if quick else WINDOWS
	if only_window != "":
		windows = WINDOWS.filter(func(w): return w[0] == only_window)
	var sizes: Array = [TEXT_SIZES[0], TEXT_SIZES[3]] if quick else TEXT_SIZES
	for w in windows:
		DisplayServer.window_set_size(w[1])
		root.size = w[1]
		for i in 8:
			await process_frame
		print("window %s: %s, screen %s" % [w[0], DisplayServer.window_get_size(), root.get_visible_rect().size])
		for t in sizes:
			_node("Settings").set_value("text_scale", t[1])
			for i in 2:
				await process_frame
			for screen in _screens():
				await _check(screen, "%s_%s" % [w[0], t[0]])
	# Last, the title screen (it's a scene of its own, so the empty stage goes)
	var w_last: Array = windows[windows.size() - 1]
	change_scene_to_file("res://scenes/title/title.tscn")
	for i in 20:
		await process_frame
	for t in sizes:
		_node("Settings").set_value("text_scale", t[1])
		for i in 4:
			await process_frame
		await _check(["title", func(): pass, func(): pass], "%s_%s" % [w_last[0], t[0]])
	_finish()


# ----------------------------------------------------------------------------- the screens
func _screens() -> Array:
	var list: Array = []
	var shop := _node("Shop")
	for stall in shop.stall_blurbs:
		list.append(["shop_" + str(stall).to_snake_case(), func(): shop.open(stall), func(): shop.close()])
	for stall in ["Wardrobe", "Decorate"]:
		list.append(["shop_" + stall.to_lower(), func(): shop.open(stall), func(): shop.close()])
	var pm := _node("PlayerMenu")
	for pair in pm.SHEETS:
		list.append(["menu_" + pair[0], func(): pm.open(pair[0]), func(): pm.close()])
	var pause := _node("PauseMenu")
	list.append(["pause", func(): pause.open(), func(): pause.close()])
	var dlg := _node("Dialogue")
	list.append(["talk_long_line", func(): _talk(false), func(): dlg.end()])
	list.append(["talk_choices", func(): _talk(true), func(): dlg.end()])
	var creator := _node("Creator")
	list.append(["creator", func(): _stand_in(); creator.open(false), func(): creator.close()])
	var tips := _node("Tips")
	list.append(["tip", func(): _tip(), func(): tips.clear()])
	var watches := _node("Watches")
	list.append(["watch_card", func(): watches.show_card(watches.WATCHES[0]),
		func(): _hide_watch_card()])
	var outfits := _node("QuickOutfits")
	list.append(["outfit_wheel", func(): outfits.open_wheel(), func(): outfits.close(false)])
	var lesson := _node("SkateLesson")
	list.append(["skate_lesson_offer", func(): lesson.offer(true), func(): lesson.answer(false)])
	# The quest card that slides in at the top right (Hayden, 14 Nov 2026: Melanie's slide quest), with the longest
	# quest step there is, and the voice in your mind at the top of the screen
	var quests := _node("Quests")
	list.append(["quest_banner", func(): _banner(), func(): quests._note_time = 0.0; quests._note.modulate.a = 0.0])
	var mind := _node("DivineMind")
	list.append(["voice_in_your_mind", func(): mind.say([LONG_VOICE]), func(): _hush(mind)])
	return list


const LONG_VOICE := "Do you feel that? The Shift has broken somewhere new. Follow the tremor, little one, and don't be afraid of the dark."


func _banner() -> void:
	var quests := _node("Quests")
	var longest := ""
	var name := ""
	for id in quests._order:
		for step in quests.quest(id).get("steps", []):
			var t := str(step.get("text", ""))
			if t.length() > longest.length():
				longest = t
				name = str(quests.quest(id).get("name", id))
	quests._announce("New quest: " + name, longest)
	if quests._note_tween:
		quests._note_tween.kill()
	quests._note.scale = Vector2.ONE
	quests._note.position.x = quests._note_x()


func _hush(mind: Node) -> void:
	if mind.has_method("clear"):
		mind.clear()


var _talker: Node3D
var _hero: Node3D


func _stand_in() -> void:
	# The creator needs someone to dress: a stand-in hero with no model (the panels are what's being checked)
	if _hero != null:
		return
	var s := GDScript.new()
	s.source_code = "extends Node3D\nvar rider := \"hero\"\nvar input_locked := false\nfunc set_rider(_w, _x := false) -> void:\n\tpass\n"
	s.reload()
	_hero = Node3D.new()
	_hero.set_script(s)
	_hero.add_to_group("player")
	var visual := Node3D.new()
	visual.name = "Visual"
	_hero.add_child(visual)
	current_scene.add_child(_hero)


func _tip() -> void:
	var tips := _node("Tips")
	_node("Settings").tips = true
	tips.clear()
	if tips.get("_seen") is Dictionary:
		tips._seen.clear()
	tips.show_tip(tips.TIPS.keys()[0])
	_node("Settings").tips = false


func _talk(choices: bool) -> void:
	if _talker == null:
		var s := GDScript.new()
		s.source_code = "extends Node3D\nfunc begin_talk() -> void:\n\tpass\nfunc end_talk() -> void:\n\tpass\n"
		s.reload()
		_talker = Node3D.new()
		_talker.set_script(s)
		current_scene.add_child(_talker)
	var dlg := _node("Dialogue")
	dlg.say(_talker, "Bramble", ["Oh, hello there! Could you help me fill the window boxes with flowers? The whole street would look so pretty, and everyone would be ever so pleased with you."])
	dlg._shown = 9999.0
	if choices:
		dlg._show_choice([{"text": "Yes please, I'd love to help you with the flowers!"}, {"text": "Maybe later, I've got a race at the Lake Loop."},
			{"text": "What's the Humming Oak?"}])


func _hide_watch_card() -> void:
	var w := _node("Watches")
	w._card.visible = false


# ----------------------------------------------------------------------------- measuring
func _check(screen: Array, setup: String) -> void:
	var n: String = screen[0]
	screen[1].call()
	for i in 6:
		await process_frame
	var vp := root.get_visible_rect()
	var bad := _overflows(vp)
	_checked += 1
	if bad.size() > 0:
		problems.append("%s @ %s (screen %dx%d): %s" % [n, setup, vp.size.x, vp.size.y, ", ".join(bad.slice(0, 6))])
		print("CUT OFF  %s @ %s: %s" % [n, setup, ", ".join(bad.slice(0, 6))])
	if out_dir != "":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir.path_join("%s__%s.png" % [setup, n]))
	screen[2].call()
	paused = false
	for i in 3:
		await process_frame


func _overflows(_vp: Rect2) -> Array[String]:
	# The shared rules (tools/ui_watch.gd): off the screen, words bigger than their box, words spilling out of their window
	return UI_WATCH.scan(root)


func _faded(n: Node) -> bool:
	while n:
		if n is CanvasItem and (n as CanvasItem).modulate.a < 0.02:
			return true
		n = n.get_parent()
	return false


func _short_path(n: Node) -> String:
	var parts := str(n.get_path()).split("/")
	return "/".join(parts.slice(2, 4)) if parts.size() > 2 else str(n.get_path())


func _screen_rect(ctl: Control) -> Rect2:
	var xf := ctl.get_global_transform_with_canvas()
	return xf * Rect2(Vector2.ZERO, ctl.size)


func _clip_rect(ctl: Control, vp: Rect2) -> Rect2:
	# What a ScrollContainer (or any box that clips) round it lets you see; past that it scrolls and that's fine
	var clip := Rect2(-1e6, -1e6, 2e6, 2e6)
	var p := ctl.get_parent()
	while p:
		if p is Control and ((p as Control).clip_contents or p is ScrollContainer):
			var pr := _screen_rect(p)
			clip = clip.intersection(pr) if clip.intersects(pr) else Rect2()
		p = p.get_parent()
	return clip


func _all_controls(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is CanvasLayer and not (c as CanvasLayer).visible:
			continue
		if c is Control:
			out.append(c)
		out.append_array(_all_controls(c))
	return out


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	print("\nUI audit: %d screens checked, %d cut off" % [_checked, problems.size()])
	for p in problems:
		print("  " + p)
	quit(1 if problems.size() > 0 else 0)

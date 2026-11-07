extends SceneTree

# Screenshots of the kid-friendly UI pass (Hayden's 7 Nov 2026 playtest): the smaller HUD with its to-do list, the
# calmer talking text (part-typed and whole), the player menu's picture tabs and the menu tour, and the pause menu's
# pictures. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_kid_ui.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.kid_ui_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.kid_ui_capture_backup.cfg"

var out_dir := "user://kid_ui_shots"
var _had_save := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	create_timer(900.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	_had_save = FileAccess.file_exists(SAVE)
	if _had_save and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var game := root.get_node("Game")
	game._resume = {}
	game.pending_message = ""
	game.needs_creator = false
	var settings := root.get_node("Settings")
	settings.tips = false
	settings.minimap = true
	var dialogue := root.get_node("Dialogue")
	var quests := root.get_node("Quests")
	dialogue.reset()
	quests.reset()
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.set_time(1, 11 * 60.0, true)
	change_scene_to_file("res://scenes/town/town.tscn")
	for i in 12:
		await process_frame
	var p := current_scene.find_child("Player", true, false) as Node3D
	p.global_position = Vector3(50, 1.0, 44)
	for i in 10:
		await process_frame
	# A quest with a checklist: the to-do list under the (smaller) stats
	dialogue.flags["bramble_flowers_start"] = true
	quests.check()
	dialogue.flags["rex_campaign_start"] = true
	quests.check()
	for i in 10:
		await process_frame
	await _shot("01_small_hud_quest_banner")
	quests._note_time = 0.0                             # the banner's gone: just the to-do list
	quests._note.modulate.a = 0.0
	for i in 8:
		await process_frame
	await _shot("02_small_hud_todo_list")
	# Talking: the line types out in place
	var talker_script := GDScript.new()
	talker_script.source_code = "extends Node3D\nfunc begin_talk() -> void:\n\tpass\nfunc end_talk() -> void:\n\tpass\n"
	talker_script.reload()
	var talker := Node3D.new()
	talker.set_script(talker_script)
	current_scene.add_child(talker)
	dialogue.say(talker, "Bramble", ["Oh, hello there! Could you help me fill the window boxes with flowers? The whole street would look so pretty."])
	for i in 3:
		await process_frame
	dialogue._shown = 48.0                              # part-way through the line
	dialogue._text.visible_characters = 48
	await _shot("03_talking_text_typing")
	dialogue._finish_typing()
	for i in 4:
		await process_frame
	await _shot("04_talking_text_whole_line")
	dialogue.end()
	for i in 10:
		await process_frame
	# The menu: picture tabs, a sentence about each page, key chips along the bottom, and the tour
	var menu := root.get_node("PlayerMenu")
	menu.open("quests")
	menu.start_tour()
	for i in 10:
		await process_frame
	await _shot("05_menu_tour_start")
	menu.tour.step(1)
	menu.tour.step(1)
	for i in 10:
		await process_frame
	await _shot("06_menu_tour_goals")
	menu.tour.step(1)
	for i in 10:
		await process_frame
	await _shot("07_menu_tour_map")
	menu.tour.stop()
	menu.show_sheet("hero")
	for i in 6:
		await process_frame
	await _shot("08_menu_picture_tabs_hero")
	menu.close()
	for i in 4:
		await process_frame
	var pause := root.get_node("PauseMenu")
	pause.open()
	for i in 6:
		await process_frame
	await _shot("09_pause_menu_pictures")
	pause.close()
	for i in 4:
		await process_frame
	_finish()


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	elif not _had_save:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	quit()

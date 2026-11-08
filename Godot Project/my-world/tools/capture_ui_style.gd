extends SceneTree

# Screenshots of the shared menu look (scripts/ui_style.gd): the quest cards and the quest banner, the folder tabs of
# the player menu and Settings, the pause menu, a shop and the wardrobe, and the round minimap with its compass in
# The Void and on Earth. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_ui_style.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.ui_style_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.ui_style_capture_backup.cfg"

var out_dir := "user://ui_style_shots"
var _had_save := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	create_timer(300.0, true, false, true).timeout.connect(_finish)
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
	# A quest starts: the banner slides in, over the round minimap
	dialogue.flags["rex_campaign_start"] = true
	quests.check()
	for i in 10:
		await process_frame
	await _shot("01_quest_banner_and_round_minimap")
	dialogue.flags["asked_dash"] = true
	dialogue.flags["bramble_flowers_start"] = true
	dialogue.flags["pip_lamps_start"] = true
	quests.check()
	for i in 10:
		await process_frame
	var menu := root.get_node("PlayerMenu")
	menu.open("quests")
	for i in 10:
		await process_frame
	await _shot("02_quest_cards")
	menu.show_sheet("settings")
	for i in 6:
		await process_frame
	await _shot("03_folder_tabs_settings")
	menu.show_sheet("hero")
	for i in 6:
		await process_frame
	await _shot("04_chunky_buttons_hero")
	menu.close()
	for i in 4:
		await process_frame
	var pause := root.get_node("PauseMenu")
	pause.open()
	for i in 6:
		await process_frame
	await _shot("05_pause_menu")
	pause.close()
	for i in 4:
		await process_frame
	var shop := root.get_node("Shop")
	shop.open("Market")
	for i in 8:
		await process_frame
	await _shot("06_market_stall")
	shop.close()
	shop.open("Wardrobe")
	for i in 8:
		await process_frame
	await _shot("07_wardrobe")
	shop.close()
	for i in 4:
		await process_frame
	# Earth: the same minimap look
	change_scene_to_file("res://scenes/earth/earth.tscn")
	for i in 14:
		await process_frame
	p = current_scene.find_child("Player", true, false) as Node3D
	p.global_position = Vector3(0, 1.0, -40)
	for i in 20:
		await process_frame
	await _shot("08_round_minimap_on_earth")


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

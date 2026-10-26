extends SceneTree

# Screenshots of the player menu (scripts/player_menu.gd): each sheet in town (Quests, Map, Hero, Bag, Skate,
# Settings, Save), the Controls settings with the Player menu key and button, and the hints on a controller. Opens a
# window (screenshots need rendering, so not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_player_menu.gd -- <output folder>
#
# The folder defaults to user://player_menu_shots. Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://player_menu_shots"
var menu: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	create_timer(120.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	# Put your save aside. If a backup is already there, an earlier run stopped before putting it back: that backup
	# is your real save, so keep it rather than copying this run's save over it.
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	var dialogue := root.get_node("Dialogue")
	var quests := root.get_node("Quests")
	var settings := root.get_node("Settings")
	menu = root.get_node("PlayerMenu")
	game._resume = {}
	game.pending_message = ""
	game.hero["name"] = "Sofi"
	game.hero["pronouns"] = "she"
	game.sparkles = 27
	for item in ["skateboard", "star_sticker", "flower_crown", "heart_shades", "cozy_scarf", "super_cape"]:
		if not game.has_item(item):
			game.items.append(item)
	dialogue.reset()
	quests.reset()
	quests.load_data({"rex_campaign": {"step": 0, "since_day": 1}})
	dialogue.flags["asked_dash"] = true
	dialogue.flags["skate_lesson_push"] = true
	dialogue.flags["skate_lesson_ollie"] = true
	dialogue.flags["skate_goal_grind"] = true
	dialogue.flags["skate_letter_S"] = true
	settings.last_device = "keyboard"
	root.get_node("Clock").set_time(1, 13 * 60.0, true)
	change_scene_to_file(TOWN)
	await _frames(8)
	var player := current_scene.find_child("Player", true, false) as Node3D
	player.global_position = Vector3(-60, 2, 40)
	await create_timer(2.5).timeout

	var n := 1
	for pair in menu.SHEETS:
		menu.open(pair[0])
		await _frames(4)
		await _capture("%02d_%s" % [n, pair[0]])
		n += 1
	# The Controls tab, scrolled down to the Player menu's key and button
	menu.show_sheet("settings")
	await _frames(2)
	var tabs := menu._body.find_child("SettingsTabs", true, false) as TabContainer
	tabs.current_tab = 1
	await _frames(3)
	var scroll := tabs.get_current_tab_control() as ScrollContainer
	for l in scroll.find_children("*", "Label", true, false):
		if (l as Label).text == "Player menu":
			scroll.ensure_control_visible(l)
			var pad := scroll.find_child("Pad player_menu", true, false) as Button
			if pad:
				pad.grab_focus()
	await _frames(4)
	await _capture("%02d_controls_player_menu" % n)
	n += 1
	# On a controller the hints say LB / RB and Back
	settings.last_device = "pad"
	settings.device_changed.emit()
	menu.show_sheet("hero")
	await _frames(4)
	await _capture("%02d_hero_on_a_controller" % n)
	settings.last_device = "keyboard"
	menu.close()
	_finish()


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()


func _capture(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _frames(count: int) -> void:
	for i in count:
		await process_frame

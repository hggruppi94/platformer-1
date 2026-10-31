extends SceneTree

# Screenshots of the start of the game and the menus added with it (plan prompts F2 to F6): the title screen over
# Galaxity at dawn (with a save, and its New Game question), each part of the opening, the loading screen, the Goals
# page, night 2's arrival and Pip at the portal, a pop with the new feedback, and the new settings (Screen shake,
# Controller rumble, Playtest notes on Assist; Voices on Audio). Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_title.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.title_capture_backup.json"
const TITLE := "res://scenes/title/title.tscn"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"

var out_dir := "user://title_shots"
var game: Node
var clock: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(1500.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	game = root.get_node("Game")
	clock = root.get_node("Clock")
	var dialogue := root.get_node("Dialogue")
	var quests := root.get_node("Quests")
	root.get_node("Settings").tips = false
	clock.pulls_home = false

	# --- The title screen, with a save ---
	game.hero["name"] = "Sunny"
	game.needs_creator = false
	game.play_time = 2 * 3600.0 + 14 * 60.0
	root.get_node("Requests").nights = 2
	game._resume = {"scene": EARTH, "position": [0.0, 1.0, 16.0], "yaw": 0.0}
	game.save_game()
	change_scene_to_file(TITLE)
	await _frames(30)
	await create_timer(3.0).timeout
	await _shot("01_title_screen")
	var t = current_scene
	t._ask_new_game()
	await _shot("02_new_game_asks_first")
	t._close_confirm()
	t._open_settings()
	await _shot("03_title_settings")
	t._close_settings()

	# --- The opening ---
	t.play_opening()
	var want := {"earth": ["04_opening_stars_hollow", 3.5], "oak": ["05_opening_the_oak_hums", 4.0],
		"galaxity": ["06_opening_outside_of_time", 3.5], "watches": ["07_opening_the_watches", 3.5],
		"you": ["08_opening_one_of_them_is_you", 1.5]}
	var taken := {}
	var until := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < until and is_instance_valid(t) and current_scene == t:
		await process_frame
		var shot := str(t.opening_shot)
		if want.has(shot) and not taken.has(shot):
			taken[shot] = true
			await create_timer(float(want[shot][1])).timeout
			if is_instance_valid(t) and current_scene == t:
				Engine.time_scale = 0.0              # hold the opening still while the (slow) shot is taken
				await _shot(str(want[shot][0]), 2)
				Engine.time_scale = 1.0
	await _wait_for_scene(EARTH, 600)
	var creator := root.get_node("Creator")
	await _frames(10)
	if creator.is_open():
		creator.close()
	await _frames(10)

	# --- The loading screen ---
	game.go(TOWN, "FromPortaltoEarth", "Galaxity")
	await _shot("09_loading_screen", 0)
	await _wait_for_scene(TOWN, 600)
	await create_timer(2.0).timeout

	# --- Night 2: arriving, Pip at the portal, the Goals page ---
	dialogue.reset()
	quests.reset()
	dialogue.set_flag("first_night_start")
	quests.check()
	for i in 20:
		if quests.is_done("first_night"):
			break
		quests.skip("first_night")
	root.get_node("Requests").nights = 2
	clock.set_earth_time(0.3 * 60.0, true)
	clock.set_time(clock.day, 9 * 60.0, true)
	change_scene_to_file(EARTH)
	await _wait_for_scene(EARTH, 600)
	change_scene_to_file(TOWN)
	await _wait_for_scene(TOWN, 600)
	await create_timer(4.0).timeout
	await _shot("10_night_2_arrives")
	var pip := _talker("pip")
	if pip:
		var body := pip.get_parent() as Node3D
		body.global_position = Vector3(31.5, body.global_position.y, 15.3) + Vector3(2, 0, 2)
		var player := current_scene.find_child("Player", true, false) as Node3D
		player.global_position = body.global_position + body.global_basis.z * 2.2 + Vector3(0, 0.8, 0)
		await _frames(10)
		dialogue.talk_to(pip)
		await _frames(4)
		dialogue._finish_typing()
		await _shot("11_pip_waits_at_the_portal")
		dialogue.end()
	var menu := root.get_node("PlayerMenu")
	menu.open("goals")
	await _shot("12_the_goals_page")
	menu.close()
	await _frames(4)

	# --- A pop, with the new feedback ---
	var gloops := current_scene.find_children("Gloop *", "", true, false)
	var player := current_scene.find_child("Player", true, false) as Node3D
	if not gloops.is_empty() and player:
		var g := gloops[0] as Node3D
		player.global_position = g.global_position + Vector3(0, 1, 4)
		await _frames(10)
		root.get_node("Juice").hit(current_scene, g.global_position + Vector3(0, 1, 0), Color(0.6, 1.0, 0.5), true)
		await _frames(3)
		await _shot("13_a_big_pop", 1)

	# --- The new settings ---
	menu.open("settings")
	await _frames(4)
	for tabs in menu.root.find_children("*", "TabContainer", true, false):
		for i in (tabs as TabContainer).get_tab_count():
			var title := (tabs as TabContainer).get_tab_title(i)
			if title == "Assist" or title == "Audio":
				(tabs as TabContainer).current_tab = i
				await _shot("14_settings_" + title.to_lower())
	menu.close()

	# --- The opening's watches, held still (the slow cloud renderer can miss them while it plays) ---
	change_scene_to_file(TITLE)
	await _wait_for_scene(TITLE, 600)
	t = current_scene
	t.menu_box.visible = false
	for c in t.ui.get_child(0).get_children():
		if c is Label and c != t.caption:
			c.visible = false
	t._watch_stage()
	t.opening_on = true
	t._cam_len = 0.01
	await create_timer(1.5).timeout
	t.caption.text = str(t.OPENING[4][1])
	t.caption.modulate.a = 1.0
	await _shot("07_opening_the_watches")
	t.caption.text = str(t.OPENING[5][1])
	await _shot("08_opening_one_of_them_is_you")
	_finish()


func _talker(id: String) -> Area3D:
	for a in current_scene.find_children("Talk", "Area3D", true, false):
		if a.get("character_id") == id:
			return a
	return null


func _shot(file: String, settle := 8) -> void:
	for i in settle:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _wait_for_scene(path: String, frames := 200) -> void:
	for i in frames:
		await process_frame
		if current_scene and current_scene.scene_file_path == path:
			break
	await _frames(6)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")
	quit(0)

extends SceneTree

# Checks the title screen, the opening and the loading screen (scripts/title_screen.gd, scripts/loading_screen.gd,
# plan prompt F5): the game opens on the title; with a save, Continue shows the hero's name, the night and the play
# time and takes you back where you were; the clock doesn't run and nothing autosaves while the title's up, and the
# clock's put back as it was; Settings opens and closes; New Game asks first when there's a save; the opening plays
# all the way through to the creator, or skips at once with a button; a new game starts at home on Earth; and the
# loading screen shows between Earth and Galaxity (with a tip) but not for a door into a shop.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_title.gd
#
# Your own save is put aside (under its own name) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.title_backup.json"
const TITLE := "res://scenes/title/title.tscn"
const EARTH := "res://scenes/earth/earth.tscn"
const TOWN := "res://scenes/town/town.tscn"
const CAFE := "res://scenes/interiors/cafe.tscn"

var failures := 0
var game: Node
var clock: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(300.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_put_save_back()
		quit(1))
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	game = root.get_node("Game")
	clock = root.get_node("Clock")
	var loading := root.get_node("Loading")
	check(ProjectSettings.get_setting("application/run/main_scene") == TITLE, "the game opens on the title screen")
	check(game.START_SCENE == EARTH, "...and a game starts from Earth")

	# --- With a save ---
	game.hero["name"] = "Sunny"
	game.needs_creator = false
	game.play_time = 3960.0
	root.get_node("Requests").nights = 3
	clock.set_earth_time(14 * 60.0, true)
	game._resume = {"scene": EARTH, "position": [0.0, 1.0, 16.0], "yaw": 0.0}
	game.save_game()
	game._resume = {"scene": EARTH, "position": [0.0, 1.0, 16.0], "yaw": 0.0}
	var minutes_before: float = clock.minutes
	change_scene_to_file(TITLE)
	await _frames(10)
	var t := current_scene
	var earth_before: float = clock.earth_minutes
	game.play_time = 3960.0
	check(t != null and t.scene_file_path == TITLE and t.cam != null and t.cam.current, "the title screen is up, with its own camera")
	check(t._bg != null and t._bg.find_child("Player", true, false) == null, "...Galaxity behind it, with nobody playing")
	check(is_equal_approx(clock.minutes, t.DAWN), "...at dawn")
	var cont: Button = t.continue_button
	check(cont != null and cont.visible, "with a save there's a Continue button")
	var info := t.menu_box.get_node_or_null("SaveInfo") as Label
	check(info != null and info.text.contains("Sunny") and info.text.contains("Night 3") and info.text.contains("1 h 6 min"),
		"...showing the hero, the night and the play time (%s)" % (info.text if info else "none"))
	await _frames(2)
	check(cont.has_focus(), "...and it has the focus, for a controller")
	for name in ["New Game", "Settings", "Quit"]:
		check(t.menu_box.get_node_or_null(name) is Button, "there's a %s button" % name)
	await create_timer(1.2).timeout
	check(is_equal_approx(clock.earth_minutes, earth_before), "the clock doesn't run on the title screen")
	check(is_equal_approx(game.play_time, 3960.0), "...and it isn't counted as play time")
	var p0: Vector3 = t.cam.global_position
	await create_timer(0.5).timeout
	check(t.cam.global_position.distance_to(p0) > 0.05, "the camera drifts slowly over the town")
	# Settings
	t._open_settings()
	await _frames(3)
	check(t.settings_panel.visible and t.settings_panel.find_children("*", "TabContainer", true, false).size() > 0,
		"Settings opens the settings tabs")
	t._close_settings()
	await _frames(2)
	check(not t.settings_panel.visible and t.menu_box.visible, "...and Back closes them")
	# New Game asks first
	t._ask_new_game()
	await _frames(2)
	check(t.confirm_panel.visible and not t.opening_on, "New Game with a save asks first")
	(t.confirm_panel.get_node("Box/No") as Button).pressed.emit()
	await _frames(2)
	check(not t.confirm_panel.visible and t.menu_box.visible, "...and No goes back")
	# Continue
	cont.pressed.emit()
	await _wait_for_scene(EARTH)
	check(current_scene.scene_file_path == EARTH, "Continue goes back where the save was")
	check(absf(clock.earth_minutes - earth_before) < 3.0 and is_equal_approx(clock.minutes, minutes_before),
		"...with the clock put back as it was (Earth %s; Galaxity %.1f, was %.1f)" % [clock.earth_time_string(), clock.minutes, minutes_before])
	await create_timer(1.6).timeout
	check(not loading.showing, "...and the loading screen's gone once it's there")

	# --- The loading screen ---
	game.go(TOWN, "FromPortaltoEarth", "Galaxity")
	await _frames(1)
	check(loading.showing and loading.tip != "" and loading._panel.visible, "Earth to Galaxity shows the loading screen, with a tip")
	await _wait_for_scene(TOWN)
	await create_timer(2.0).timeout
	check(not loading.showing and not loading._panel.visible, "...and it goes once Galaxity's ready")
	if ResourceLoader.exists(CAFE):
		game.go(CAFE, "Entrance", "cafe")
		await _frames(1)
		check(not loading.showing, "a door into a shop doesn't show it")
		await _wait_for_scene(CAFE)

	# --- New Game, the whole opening ---
	change_scene_to_file(TITLE)
	await _frames(10)
	t = current_scene
	t._ask_new_game()
	await _frames(2)
	(t.confirm_panel.get_node("Box/Yes") as Button).pressed.emit()
	await _frames(2)
	check(t.opening_on, "Yes plays the opening")
	var seen := []
	var until := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < until:
		await process_frame
		if not is_instance_valid(t) or current_scene != t:
			break
		if not t.opening_shot in seen:
			seen.append(t.opening_shot)
	check(seen.has("earth") and seen.has("oak") and seen.has("galaxity") and seen.has("watches") and seen.has("you"),
		"the opening shows Stars Hollow, the oak, Galaxity, the watches and \"you\" (%s)" % [seen])
	await _wait_for_scene(EARTH)
	check(current_scene.scene_file_path == EARTH and game.needs_creator and game.play_time < 10.0,
		"...then a new game starts at home on Earth, ready to make a hero (%s, %s, %.1f)" % [current_scene.scene_file_path,
		game.needs_creator, game.play_time])

	# --- Skipping it, with no save ---
	DirAccess.remove_absolute(SAVE)
	change_scene_to_file(TITLE)
	await _frames(10)
	t = current_scene
	check(t.continue_button == null, "with no save, there's no Continue")
	t._ask_new_game()
	await _frames(2)
	check(t.opening_on and not t.confirm_panel.visible, "...and New Game goes straight to the opening")
	await create_timer(1.0).timeout
	var ev := InputEventAction.new()
	ev.action = "jump"
	ev.pressed = true
	t._unhandled_input(ev)
	var at := Time.get_ticks_msec()
	await _wait_for_scene(EARTH, 600)
	check(current_scene.scene_file_path == EARTH and (Time.get_ticks_msec() - at) < 6000,
		"pressing Jump skips it at once (%d ms)" % (Time.get_ticks_msec() - at))

	_put_save_back()
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)


func _wait_for_scene(path: String, frames := 300) -> void:
	for i in frames:
		await process_frame
		if current_scene and current_scene.scene_file_path == path:
			break
	await _frames(4)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _put_save_back() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")

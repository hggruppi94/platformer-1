extends SceneTree

# Checks the clocks and the Shift (scripts/clock.gd): Earth's clock always runs, Galaxity's only in the Shift (Earth's
# midnight to 1 AM), which lasts one whole Galaxity day from dawn to dawn. Then sleeping in the player's bed on Earth,
# sleeping in Galaxity until the Shift ends, old saves loading, and saving/loading the time (bed.gd, game.gd).
# Run it twice: the first run saves at home on Earth, the second starts up like the real game and checks it came back.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_clock.gd
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_clock.gd -- --check-load
#
# Your own save is put aside first (user://save.test_backup.json) and put back by the --check-load run.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const EARTH := "res://scenes/earth/earth.tscn"
const TOWN := "res://scenes/town/town.tscn"
const HOUSE := "res://scenes/interiors/ninas_house.tscn"

var failures := 0
var clock: Node
var game: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	# Never hang: give up after a few minutes (your save stays safe in the backup until --check-load puts it back)
	create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		quit(1))
	clock = root.get_node("Clock")
	game = root.get_node("Game")
	if "--check-load" in OS.get_cmdline_user_args():
		_check_load.call_deferred()        # after the autoloads are ready (Game loads the save then)
	else:
		_run.call_deferred()


func _run() -> void:
	# Put your save aside. If a backup is already there, an earlier run stopped before putting it back: that backup
	# is your real save, so keep it rather than copying this run's test save over it.
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	game._resume = {}            # the save loaded on start-up would put her back where she was; this test starts fresh
	var events: Array[String] = []
	clock.shift_started.connect(func() -> void: events.append("started"))
	clock.shift_ended.connect(func() -> void: events.append("ended"))
	clock.pulls_home = false     # (no scene changes while the clock is checked on its own)

	# A new game: Earth's evening, Galaxity waiting at dawn on day 1
	clock.reset()
	check(clock.earth_time_string() == "8:00 PM" and clock.day == 1 and clock.time_string() == "7:00 AM" and not clock.in_shift(),
		"new game: Earth 8:00 PM, Galaxity day 1, 7:00 AM")

	# On Earth outside the Shift: an Earth hour a real minute, and Galaxity waits
	clock.on_earth = true
	clock.set_earth_time(12 * 60.0, true)
	clock._process(10.0)
	check(is_equal_approx(clock.earth_minutes, 12 * 60.0 + 10.0) and clock.time_string() == "7:00 AM",
		"Earth: 10 s = 10 Earth minutes; Galaxity's clock waits (%s)" % clock.time_string())
	check(clock.hour() == 12 and clock.period() == "day", "on Earth the hour is Earth's (%d, %s)" % [clock.hour(), clock.period()])

	# Midnight on Earth: the Shift starts, and Galaxity's day begins at dawn (moved on to it if it was elsewhere)
	clock.on_earth = false
	clock.set_time(3, 15 * 60.0, true)
	clock.on_earth = true
	clock.set_earth_time(23 * 60.0 + 59.5, true)
	events.clear()
	clock._process(1.0)
	check(clock.in_shift() and events == ["started"], "Earth's midnight: the Shift started (%s)" % [events])
	check(clock.day == 4 and absf(clock.minutes - 7 * 60.0) < 1.0, "...and Galaxity's day 4 begins at dawn (%s)" % clock.time_string())

	# In the Shift: Galaxity's day runs at full speed, and Earth's clock crawls along with it, wherever she is
	var g0: float = clock.minutes
	var e0: float = clock.earth_minutes
	clock._process(10.0)
	var gal_rate: float = 1440.0 / (clock.DAY_LENGTH_MINUTES * 60.0)
	check(is_equal_approx(clock.minutes - g0, 10.0 * gal_rate), "Shift: 10 s = %.1f Galaxity minutes" % (clock.minutes - g0))
	check(is_equal_approx((clock.earth_minutes - e0) * clock.SHIFT_RATIO, clock.minutes - g0),
		"...and Earth's clock goes %dx slower (%.2f min)" % [int(clock.SHIFT_RATIO), clock.earth_minutes - e0])
	var shift_real_minutes: float = 60.0 / ((clock.earth_minutes - e0) / 10.0) / 60.0
	check(is_equal_approx(shift_real_minutes, clock.DAY_LENGTH_MINUTES),
		"one Earth hour in the Shift lasts a whole Galaxity day (%.0f real minutes)" % shift_real_minutes)

	# The end of the Shift: Earth's 1 AM is Galaxity's next dawn, exactly
	clock.on_earth = false
	clock.set_time(5, 6 * 60.0 + 59.0, true)                       # (one minute before the next dawn)
	check(clock.in_shift() and absf(clock.earth_minutes - (60.0 - 1.0 / clock.SHIFT_RATIO)) < 0.01,
		"Galaxity's 6:59 AM is Earth's 12:59 AM (%s)" % clock.earth_time_string())
	events.clear()
	clock._process(5.0)
	check(not clock.in_shift() and events == ["ended"], "1 AM: the Shift ended (%s)" % [events])
	check(clock.day == 5 and clock.time_string() == "7:00 AM" and clock.earth_time_string() == "1:00 AM",
		"...right at Galaxity's dawn: day %d, %s, Earth %s" % [clock.day, clock.time_string(), clock.earth_time_string()])
	clock._process(10.0)
	check(clock.time_string() == "7:00 AM", "Galaxity waits at dawn for the next Shift")

	# Jumps in Galaxity keep Earth's clock in step
	clock.set_time(5, 13 * 60.0, true)
	check(clock.in_shift() and is_equal_approx(clock.earth_minutes, 15.0) and clock.hour() == 13,
		"Galaxity's 1 PM is Earth's 12:15 AM (%s)" % clock.earth_time_string())
	check(is_equal_approx(clock.shift_minutes_left(), 18 * 60.0), "18 Galaxity hours left of the Shift")
	clock.set_time(5, 3 * 60.0, true)
	clock.sleep_until_morning()
	check(clock.day == 5 and clock.hour() == 7 and clock.minute() == 0, "sleep_until_morning at 3 AM -> day 5, 7:00 AM")
	clock.set_time(5, 23 * 60.0, true)
	clock.advance(12 * 60.0 + 30.0)
	check(clock.day == 6 and clock.time_string() == "11:30 AM", "advance 12.5 hours from 11 PM -> day 6, 11:30 AM")

	# How long a sleep lasts. In Galaxity: no further than the end of the Shift, which ends it.
	clock.set_time(6, 13 * 60.0, true)
	check(is_equal_approx(clock.sleep_length(8 * 60.0), 8 * 60.0), "Galaxity: an 8-hour sleep at 1 PM lasts 8 hours")
	check(is_equal_approx(clock.sleep_length(20 * 60.0), 18 * 60.0), "Galaxity: 20 hours from 1 PM stops at dawn (18 hours)")
	events.clear()
	clock.sleep(clock.sleep_length(20 * 60.0))
	check(not clock.in_shift() and events == ["ended"] and clock.day == 7 and clock.time_string() == "7:00 AM",
		"sleeping until dawn in Galaxity ends the Shift (day %d, %s, %s)" % [clock.day, clock.time_string(), events])
	# On Earth: a nap stops at midnight so the Shift isn't skipped, unless she's already in it
	clock.on_earth = true
	clock.set_earth_time(14 * 60.0, true)
	check(is_equal_approx(clock.sleep_length(3 * 60.0), 3 * 60.0), "Earth: a 3-hour nap at 2 PM lasts 3 hours")
	clock.set_earth_time(21 * 60.0 + 30.0, true)
	check(is_equal_approx(clock.sleep_length(8 * 60.0), 150.0), "Earth: 8 hours from 9:30 PM stops at midnight (2.5 hours)")
	events.clear()
	clock.sleep(150.0)
	check(clock.in_shift() and events == ["started"] and clock.time_string() == "7:00 AM",
		"...and wakes her for the Shift, with Galaxity at dawn (%s)" % [events])
	check(is_equal_approx(clock.minutes_until_hour(0), 1440.0), "'until the Shift' from its very start waits for the next one")

	# Old saves: one made in Galaxity (before the player lived on Earth) carries on right there, in the Shift
	clock.on_earth = false
	_write_save({"version": 1, "scene": TOWN, "position": [0, 2, 0], "day": 3, "minutes": 19 * 60.0,
		"earth_minutes": 17 * 60.0})
	game.load_game()
	check(clock.day == 3 and clock.time_string() == "7:00 PM" and clock.in_shift() and is_equal_approx(clock.earth_minutes, 30.0),
		"an old save in town: Galaxity day 3, 7 PM, in the Shift (Earth %s)" % clock.earth_time_string())
	check(game._resume.get("scene", "") == TOWN, "...and she's back in town")
	_write_save({"version": 1, "scene": EARTH, "position": [0, 2, 0], "day": 3, "minutes": 20.0, "earth_minutes": 19 * 60.0})
	game.load_game()
	check(clock.earth_time_string() == "7:00 PM" and not clock.in_shift() and game._resume.get("scene", "") == EARTH,
		"an old save on Earth keeps Earth's time (%s)" % clock.earth_time_string())
	_write_save({"version": 1, "scene": HOUSE, "position": [0, 2, 0]})
	game.load_game()
	check(clock.in_shift() and game._resume.get("scene", "") == HOUSE, "a very old save with no clock still lands in the Shift")
	game._resume = {}
	clock.pulls_home = true

	# Sleep in the player's bed on Earth for real: fade, midnight, save
	change_scene_to_file(EARTH)
	await _frames(5)
	clock.reset()
	var player := current_scene.find_child("Player", true, false) as Node3D
	var bed := current_scene.find_child("My Home", true, false).find_child("SleepSpot", true, false)
	check(player != null and bed != null, "Earth has the player and their bed at home")
	check(clock.on_earth, "on Earth")
	player.global_position = bed.global_position + Vector3(0.0, 0.5, -1.5)
	for i in 10:
		await physics_frame
	check(bed._near, "standing by the bed shows the prompt: " + bed.get_node("Prompt").text)
	var messages: Array[String] = []
	game.message_posted.connect(func(t: String) -> void: messages.append(t))
	# Interact opens the picker (game paused); right twice: 8 -> 10 hours; Interact again picks it
	clock.set_earth_time(21 * 60 + 30.0, true)
	game.hp = 1
	_press("interact")
	await _frames(2)
	check(bed._picker != null and paused, "Interact opens the sleep picker and pauses the game")
	_press("ui_right")
	_press("ui_right")
	await _frames(2)
	check(bed.hours == 10 and bed._hours_button.text.contains("10 hours"), "right twice: " + bed._hours_button.text.strip_edges())
	check(bed._preview.text.contains("12:00 AM") and bed._preview.text.contains("Shift"), "preview: " + bed._preview.text)
	_press("interact")
	await _frames(2)
	check(bed._picker == null and paused, "picking it closes the picker and she falls asleep")
	await create_timer(5.0).timeout
	check(not paused, "...and wakes up again")
	check(clock.in_shift() and clock.earth_time_string() == "12:00 AM",
		"10 hours from 9:30 PM woke her at midnight for the Shift (Earth %s)" % clock.earth_time_string())
	check(not messages.is_empty() and messages[-1].contains("the Shift has begun"), "wake-up message: %s" % [messages])
	check(game.hp == 1 + ceili(game.max_hp * 2.5 / 8.0), "a 2.5-hour sleep fills part of her HP (%d/%d)" % [game.hp, game.max_hp])
	var hud := player.get_node("HUD")
	hud._refresh_clock()
	check(hud.clock_label.text.begins_with("Earth") and hud.clock_label.text.contains("The Shift"),
		"the HUD: \"%s\"" % hud.clock_label.text.replace("\n", " / "))
	# Cancel does nothing
	_press("interact")
	await _frames(2)
	_press("ui_cancel")
	await _frames(2)
	check(bed._picker == null and not paused and clock.earth_time_string() == "12:00 AM", "Cancel closes the picker without sleeping")
	# "Until morning" from the picker sleeps straight through the night, Shift and all
	clock.set_earth_time(22 * 60.0, true)
	_press("interact")
	await _frames(2)
	_press("ui_down")
	await _frames(2)
	check(bed._preview.text.ends_with("wake up at 7:00 AM"), "'until morning' preview: " + bed._preview.text)
	_press("interact")
	await create_timer(5.0).timeout
	check(clock.earth_time_string() == "7:00 AM" and not clock.in_shift(), "'until morning' at 10 PM -> Earth %s" % clock.earth_time_string())
	check(game.hp == game.max_hp, "a full night's sleep fills HP")

	# A bed in Galaxity, in the Shift: sleeping until morning ends it, and she wakes up back home on Earth
	clock.set_earth_time(23 * 60.0 + 59.0, true)
	clock.set_earth_time(10.0, true)
	game.go(HOUSE, "BedSpawn")
	await _wait_for_scene(HOUSE)
	check(current_scene.scene_file_path == HOUSE and clock.in_shift() and not clock.on_earth, "in Galaxity, in the Shift (%s)" % clock.time_string())
	var gbed := current_scene.find_child("SleepSpot", true, false)
	gbed.sleep_for(clock.minutes_until_hour(7))
	await _wait_for_scene(EARTH, 600)
	check(current_scene.scene_file_path == EARTH and not clock.in_shift() and clock.earth_time_string() == "1:00 AM",
		"slept until morning in Galaxity: home on Earth at %s" % clock.earth_time_string())
	await _frames(4)
	player = current_scene.find_child("Player", true, false) as Node3D
	var told: String = player.get_node("HUD").message_label.text
	check(told.contains("wakes up back home on Earth"), "\"%s\"" % told)

	# Saved at home on Earth, 7 AM
	clock.set_earth_time(7 * 60.0, true)
	game.save_game()
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	check(data is Dictionary and int(data.get("version", 0)) == 2 and is_equal_approx(float(data.get("earth_minutes", 0)), 7 * 60.0),
		"save.json (version 2) has Earth's 7:00 AM")
	check(data is Dictionary and data.get("scene") == EARTH, "save.json has her on Earth")
	print("RESULT %s (%d failed). Now run with -- --check-load" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)


func _write_save(data: Dictionary) -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()


func _wait_for_scene(path: String, frames := 200) -> void:
	for i in frames:
		await process_frame
		if current_scene and current_scene.scene_file_path == path:
			break
	await _frames(6)


func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	var up := InputEventAction.new()
	up.action = action
	Input.parse_input_event(up)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check_load() -> void:
	# Game (an autoload) has already loaded the save, as on a real start-up
	check(clock.earth_time_string() == "7:00 AM" and not clock.in_shift(), "loaded clock: Earth %s" % clock.earth_time_string())
	check(game.is_resuming() and game._resume.get("scene") == EARTH, "she'll reappear on Earth")
	check(game.START_SCENE == EARTH, "a game starts (and carries on) from Earth, after the title screen")
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)

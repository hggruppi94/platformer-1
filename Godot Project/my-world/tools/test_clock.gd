extends SceneTree

# Checks the game clock, the Shift, sleeping and saving/loading the time (scripts/clock.gd, bed.gd, game.gd).
# Run it twice: the first run saves in Nina's House, the second starts up like the real game and checks it came back.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_clock.gd
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_clock.gd -- --check-load
#
# Your own save is put aside first (user://save.test_backup.json) and put back by the --check-load run.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
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
	game._resume = {}            # the save loaded on start-up would put her back in town; this test starts fresh

	# Speed: a day takes DAY_LENGTH_MINUTES real minutes, four times slower in the Shift
	clock.set_time(3, 12 * 60.0, true)
	var start: float = clock.minutes
	clock._process(10.0)
	check(is_equal_approx(clock.minutes - start, 10.0 * 1440.0 / (clock.DAY_LENGTH_MINUTES * 60.0)), "clock speed: 10 s = %.1f game minutes" % (clock.minutes - start))

	# The Shift starts at midnight (new day), slows the clock, and ends at 1 AM
	var events: Array[String] = []
	clock.shift_started.connect(func() -> void: events.append("started"))
	clock.shift_ended.connect(func() -> void: events.append("ended"))
	clock.set_time(3, 23 * 60 + 59.5, true)
	clock._process(1.0)
	check(clock.day == 4 and clock.in_shift() and events == ["started"], "midnight: day 4, Shift started (%s)" % [events])
	start = clock.minutes
	clock._process(10.0)
	check(is_equal_approx(clock.minutes - start, 10.0 * 1440.0 / (clock.DAY_LENGTH_MINUTES * 60.0) / clock.SHIFT_SLOWDOWN), "Shift: clock runs %dx slower" % clock.SHIFT_SLOWDOWN)
	clock.set_time(4, 59.9, true)
	clock._process(1.0)
	check(not clock.in_shift() and events == ["started", "ended"], "1 AM: Shift ended")
	check(clock.time_string() == "1:00 AM", "time string: " + clock.time_string())

	# Sleeping wakes her at 7 AM: the same day if it's before then, otherwise the next
	clock.set_time(4, 3 * 60.0, true)
	clock.sleep_until_morning()
	check(clock.day == 4 and clock.hour() == 7 and clock.minute() == 0, "sleep at 3 AM -> day 4, 7:00 AM")
	clock.set_time(4, 22 * 60.0, true)
	clock.sleep_until_morning()
	check(clock.day == 5 and clock.hour() == 7, "sleep at 10 PM -> day 5, 7:00 AM")

	# How long a sleep really lasts: stops at midnight so the Shift isn't skipped, unless she's already in it
	clock.set_time(5, 14 * 60.0, true)
	check(is_equal_approx(clock.sleep_length(3 * 60.0), 3 * 60.0), "3-hour nap at 2 PM lasts 3 hours")
	clock.set_time(5, 21 * 60.0 + 30.0, true)
	check(is_equal_approx(clock.sleep_length(8 * 60.0), 150.0), "8 hours from 9:30 PM stops at midnight (2.5 hours)")
	clock.set_time(5, 20.0, true)
	check(is_equal_approx(clock.sleep_length(8 * 60.0), 8 * 60.0), "in the Shift she can sleep on through it")
	check(is_equal_approx(clock.minutes_until_hour(0), 1420.0), "'until the Shift' from inside it waits for the next one")
	clock.set_time(5, 23 * 60.0, true)
	clock.advance(12 * 60.0 + 30.0)
	check(clock.day == 6 and clock.time_string() == "11:30 AM", "advance 12.5 hours from 11 PM -> day 6, 11:30 AM")

	# Sleep in Nina's bed for real: fade, morning, save
	change_scene_to_file(HOUSE)
	for i in 5:
		await process_frame
	var player := current_scene.find_child("Player", true, false) as Node3D
	var bed := current_scene.find_child("SleepSpot", true, false)
	check(player != null and bed != null, "Nina's House has the player and a bed")
	player.global_position = bed.global_position + Vector3(0.0, 0.5, 1.5)
	for i in 10:
		await physics_frame
	check(bed._near, "standing by the bed shows the prompt: " + bed.get_node("Prompt").text)
	var messages: Array[String] = []
	game.message_posted.connect(func(t: String) -> void: messages.append(t))
	# Interact opens the picker (game paused); right twice: 8 -> 10 hours; Interact again picks it
	clock.set_time(6, 21 * 60 + 30.0, true)
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
	check(clock.day == 7 and clock.hour() == 0 and clock.minute() == 0 and clock.in_shift(),
		"10 hours from 9:30 PM woke her at midnight for the Shift: day %d, %s" % [clock.day, clock.time_string()])
	check(not messages.is_empty() and messages[-1].contains("the Shift has begun"), "wake-up message: %s" % [messages])
	check(game.hp == 1 + ceili(game.max_hp * 2.5 / 8.0), "a 2.5-hour sleep fills part of her HP (%d/%d)" % [game.hp, game.max_hp])
	# Cancel does nothing
	_press("interact")
	await _frames(2)
	_press("ui_cancel")
	await _frames(2)
	check(bed._picker == null and not paused and clock.day == 7 and clock.hour() == 0, "Cancel closes the picker without sleeping")
	# In the Shift, sleep on until morning
	bed.sleep_for(clock.minutes_until_hour(7))
	await create_timer(5.0).timeout
	check(clock.day == 7 and clock.hour() == 7, "slept on through the Shift to day 7, %s" % clock.time_string())
	check(game.hp == game.max_hp, "a full night's sleep fills HP")
	check(messages[-1].begins_with("Good morning!"), "wake-up message: " + messages[-1])
	# "Until morning" from the picker sleeps straight through the night, Shift and all
	clock.set_time(7, 22 * 60.0, true)
	_press("interact")
	await _frames(2)
	_press("ui_down")
	await _frames(2)
	check(bed._preview.text == "She'll wake up at 7:00 AM", "'until morning' preview: " + bed._preview.text)
	_press("interact")
	await create_timer(5.0).timeout
	check(clock.day == 8 and clock.hour() == 7, "'until morning' at 10 PM -> day 8, %s" % clock.time_string())
	# Back to day 7, 7:00 AM for the save/load check below
	clock.set_time(7, 7 * 60.0, true)
	game.save_game()
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	check(data is Dictionary and int(data.get("day", 0)) == 7 and is_equal_approx(float(data.get("minutes", 0)), 7 * 60.0),
		"save.json has day 7, 7:00 AM")
	check(data is Dictionary and data.get("scene") == HOUSE, "save.json has her in Nina's House")
	var p: Array = data.get("position", [0, 0, 0])
	var saved_pos := Vector3(p[0], p[1], p[2])
	check(saved_pos.distance_to(player.global_position) < 0.5, "save.json has her by the bed %s" % saved_pos)
	print("RESULT %s (%d failed). Now run with -- --check-load" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)


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
	check(clock.day == 7 and clock.hour() == 7 and clock.minute() == 0, "loaded clock: day %d, %s" % [clock.day, clock.time_string()])
	check(game.is_resuming() and game._resume.get("scene") == HOUSE, "she'll reappear in Nina's House")
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)

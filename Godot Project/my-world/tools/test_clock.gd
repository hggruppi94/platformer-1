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
	clock = root.get_node("Clock")
	game = root.get_node("Game")
	if "--check-load" in OS.get_cmdline_user_args():
		_check_load.call_deferred()        # after the autoloads are ready (Game loads the save then)
	else:
		_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE):
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
	clock.set_time(6, 21 * 60 + 30.0, true)
	game.hp = 1
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	await process_frame
	check(paused, "sleeping pauses the game")
	await create_timer(5.0).timeout
	check(not paused, "...and wakes up again")
	check(clock.day == 7 and clock.hour() == 7, "woke up on day 7 at %s" % clock.time_string())
	check(game.hp == game.max_hp, "sleeping filled HP")
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	check(data is Dictionary and int(data.get("day", 0)) == 7 and is_equal_approx(float(data.get("minutes", 0)), 7 * 60.0),
		"save.json has day 7, 7:00 AM")
	check(data is Dictionary and data.get("scene") == HOUSE, "save.json has her in Nina's House")
	var p: Array = data.get("position", [0, 0, 0])
	var saved_pos := Vector3(p[0], p[1], p[2])
	check(saved_pos.distance_to(player.global_position) < 0.5, "save.json has her by the bed %s" % saved_pos)
	print("RESULT %s (%d failed). Now run with -- --check-load" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)


func _check_load() -> void:
	# Game (an autoload) has already loaded the save, as on a real start-up
	check(clock.day == 7 and clock.hour() == 7 and clock.minute() == 0, "loaded clock: day %d, %s" % [clock.day, clock.time_string()])
	check(game.is_resuming() and game._resume.get("scene") == HOUSE, "she'll reappear in Nina's House")
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)

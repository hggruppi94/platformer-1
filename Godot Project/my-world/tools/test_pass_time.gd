extends SceneTree

# Checks Pause > "Pass the time" and "Go to the Void at midnight" (scripts/pass_time.gd; Hayden, 13 Nov 2026: "We need
# to make the game playable all the way through without forcing the player to wait"):
# - on Earth after the First Night: morning, noon, evening, night and the crack opening, soonest first, and the pause
#   menu shows both buttons; passing to the evening really moves Earth's clock there, unpauses and saves,
# - "Go to the Void at midnight" lands in the Void in the Shift,
# - in the Void: noon, evening, night, midnight, early morning (only what's left of the Shift) and dawn; noon moves the
#   Void's clock; dawn ends the Shift and the portal takes them home to Earth,
# - a quest's "hours" wait (Rex's posters) is over once the time's passed, in the same visit,
# - The First Night: the first day never passes 6 PM, its evening stops at midnight and nothing names the crack, the
#   Shift or the Void (no spoilers), and there's no quick way to the Void before the first fall,
# - no passing the time in a portal world, in a talk or on Earth while the crack's open.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_pass_time.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.pass_time_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.pass_time_test_backup.cfg"
const EARTH := "res://scenes/earth/earth.tscn"
const TOWN := "res://scenes/town/town.tscn"
var PASS_TIME: GDScript                # scripts/pass_time.gd (loaded once the autoloads are up)

var failures := 0
var game: Node
var clock: Node
var quests: Node
var dialogue: Node
var first_night: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(300.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	clock = root.get_node("Clock")
	quests = root.get_node("Quests")
	dialogue = root.get_node("Dialogue")
	first_night = root.get_node("FirstNight")
	PASS_TIME = load("res://scripts/pass_time.gd")
	root.get_node("Settings").tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	quests.state[first_night.ID] = {"step": 0, "done": true, "since_day": 1}
	dialogue.flags["oak_woken"] = true
	dialogue.flags["earth_crack_seen"] = true
	await _check_earth()
	await _check_to_the_void()
	await _check_void()
	await _check_quest_wait()
	await _check_dawn()
	await _check_first_night()
	await _check_not_here()
	_finish()


func _texts() -> Array:
	return PASS_TIME.choices().map(func(c): return str(c.text))


func _find(start: String):
	for c in PASS_TIME.choices():
		if str(c.text).begins_with(start):
			return c
	return null


func _pass(length: float) -> void:
	PASS_TIME.run(length)
	await _wait_until(func(): return root.get_node_or_null("PassTime") == null, 8.0)
	await _frames(3)


func _wait_until(cond: Callable, seconds: float) -> void:
	var t := 0.0
	while t < seconds and not cond.call():
		await process_frame
		t += 1.0 / 60.0
		await create_timer(1.0 / 60.0, true, false, true).timeout


func _load(scene: String) -> void:
	change_scene_to_file(scene)
	await _frames(12)
	await _physics(4)


func _menu_texts() -> Array:
	var pm := root.get_node("PauseMenu")
	pm.open()
	await _frames(2)
	var out := []
	for c in pm.box.get_children():
		if c is Button:
			out.append(c.text)
	pm.close()
	await _frames(2)
	return out


# --- Earth, after the first night -----------------------------------------------------------------------------------
func _check_earth() -> void:
	clock.on_earth = true
	clock.set_earth_time(1 * 60.0 + 10.0, true)          # just pulled home: 1:10 AM
	await _load(EARTH)
	check(PASS_TIME.why_not() == "", "on Earth, the time can be passed (%s)" % PASS_TIME.why_not())
	var t := _texts()
	print("      choices: %s" % [t])
	check(t.size() == 6, "six times to pass to (%d)" % t.size())
	check(t.size() > 0 and str(t[0]).begins_with("Until morning (7:00 AM)"), "soonest first: morning")
	for want in ["Until noon", "Until evening", "Until night", "Until the crack opens (12:00 AM)"]:
		check(_find(want) != null, "...%s" % want)
	var fair = null
	for c in PASS_TIME.choices():
		if "Saturday" in str(c.text):
			fair = c
	check(fair != null and str(fair.text).begins_with("Until the ") and "crack" not in str(fair.text), "...and the next Saturday fair (%s)" % [fair])
	var lengths: Array = PASS_TIME.choices().map(func(c): return float(c.minutes))
	var sorted := lengths.duplicate()
	sorted.sort()
	check(lengths == sorted, "in order")
	var menu := await _menu_texts()
	check("Pass the time" in menu, "the pause menu has Pass the time (%s)" % [menu])
	check("Go to the Void at midnight" in menu, "...and Go to the Void at midnight")

	game.save_game()
	var before := FileAccess.get_file_as_string(SAVE)
	await _pass(_find("Until evening").minutes)
	# (the clock carries on ticking while the screen fades back in: a few minutes at most)
	check(clock.earth_minutes >= 18 * 60.0 and clock.earth_minutes < 18 * 60.0 + 10.0, "passed to 6:00 PM (%s)" % clock.earth_time_string())
	check(not paused, "the game's running again")
	check(root.get_node_or_null("PassTime") == null, "the dark screen's gone")
	check(FileAccess.get_file_as_string(SAVE) != before, "it saved")
	check(current_scene.scene_file_path == EARTH, "still in Stars Hollow")


func _check_to_the_void() -> void:
	check(PASS_TIME.to_the_shift_ok(), "the quick way to the Void is there")
	PASS_TIME.go_to_the_void()
	await _wait_until(func(): return current_scene != null and current_scene.scene_file_path == TOWN, 20.0)
	await _frames(20)
	check(current_scene != null and current_scene.scene_file_path == TOWN, "Go to the Void at midnight lands in the Void")
	check(clock.in_shift() and not clock.on_earth, "...in the Shift")
	check(not paused, "...and the game's running")


# --- The Void ---------------------------------------------------------------------------------------------------------
func _check_void() -> void:
	clock.pulls_home = true
	clock.set_time(clock.day, 9 * 60.0, true)
	var t := _texts()
	print("      choices: %s" % [t])
	check(t.size() == 6, "six times to pass to in the Void (%d)" % t.size())
	check(t.size() > 0 and str(t[0]).begins_with("Until noon"), "noon first")
	check(t.size() > 0 and "home to Earth" in str(t[t.size() - 1]), "dawn last: home to Earth")
	clock.set_time(clock.day, 4 * 60.0 + 30.0, true)
	t = _texts()
	check(t.size() == 2, "at 4:30 AM only early morning and dawn are left (%s)" % [t])
	clock.set_time(clock.day, 9 * 60.0, true)
	await _pass(PASS_TIME.choices()[0].minutes)
	check(clock.minutes >= 12 * 60.0 and clock.minutes < 12 * 60.0 + 10.0, "passed to noon in the Void (%s)" % clock.time_string())
	check(clock.in_shift() and current_scene.scene_file_path == TOWN, "still in the Void, still the Shift")


func _check_quest_wait() -> void:
	var q := "rex_campaign"
	var steps: Array = quests.quest(q).steps
	var i := -1
	for k in steps.size():
		if str(steps[k].id) == "posters":
			i = k
	check(i >= 0 and int(steps[i].wait.get("hours", 0)) > 0 and int(steps[i].wait.get("days", 0)) == 0,
		"Rex's posters wait hours, not a day")
	quests.state[q] = {"step": i, "since_day": clock.day, "since_at": quests.now_at(), "done": false}
	check(quests.is_waiting(q), "...waiting straight after")
	await _pass(PASS_TIME.choices()[1].minutes)          # noon to night
	check(not quests.is_waiting(q), "...and done waiting after passing the time (%s)" % clock.time_string())
	quests.state[q] = {"step": i, "since_day": clock.day, "done": false}
	check(typeof(quests.is_waiting(q)) == TYPE_BOOL, "an old save's step (no since_at) still works")
	quests.state.erase(q)


func _check_dawn() -> void:
	var c: Array = PASS_TIME.choices()
	await _pass_home(float(c[c.size() - 1].minutes))
	check(clock.on_earth and current_scene.scene_file_path == EARTH, "passing to dawn: the portal takes them home")
	check(not clock.in_shift(), "...and the Shift's over")
	check(not paused, "...and the game's running")


func _pass_home(length: float) -> void:
	PASS_TIME.run(length)
	await _wait_until(func(): return current_scene != null and current_scene.scene_file_path == EARTH, 20.0)
	await _frames(20)


# --- The First Night: no spoilers, and its clock rules ----------------------------------------------------------------
func _check_first_night() -> void:
	var fn := first_night
	dialogue.flags.erase("oak_woken")
	quests.state[fn.ID] = {"step": 0, "done": false, "since_day": 1}      # morning
	clock.set_earth_time(14 * 60.0, true)
	var t := _texts()
	print("      morning choices: %s" % [t])
	var most := 0.0
	for c in PASS_TIME.choices():
		most = maxf(most, float(c.minutes))
	check(most <= 4 * 60.0 + 0.1, "the first day never goes past 6 PM")
	check(not ", ".join(t).to_lower().contains("crack") and not ", ".join(t).contains("Void"), "...and says nothing of the crack")
	check(not PASS_TIME.to_the_shift_ok(), "no quick way to the Void before the first fall")
	quests.state[fn.ID] = {"step": 2, "done": false, "since_day": 1}      # evening
	clock.set_earth_time(20 * 60.0, true)
	t = _texts()
	print("      evening choices: %s" % [t])
	most = 0.0
	for c in PASS_TIME.choices():
		most = maxf(most, float(c.minutes))
	check(is_equal_approx(most, 4 * 60.0), "the first evening stops at midnight (%.0f min)" % most)
	var all := ", ".join(t)
	check(not all.to_lower().contains("crack") and not all.contains("Shift") and not all.contains("Void"),
		"...and nothing names the crack, the Shift or the Void")
	var menu := await _menu_texts()
	check(not "Go to the Void at midnight" in menu, "no Go to the Void button on the first evening")
	quests.state[fn.ID] = {"step": 0, "done": true, "since_day": 1}
	dialogue.flags["oak_woken"] = true


func _check_not_here() -> void:
	clock.set_earth_time(0 * 60.0 + 20.0, true)                           # the crack's open
	check(PASS_TIME.choices().is_empty(), "on Earth in the Shift: nothing to wait for (go through instead)")
	var menu := await _menu_texts()
	check(not "Pass the time" in menu, "...so no Pass the time button")
	clock.set_earth_time(15 * 60.0, true)
	var portals := root.get_node("Portals")
	portals.here = "shard_isle"
	check(PASS_TIME.why_not() != "", "not in a portal world (%s)" % PASS_TIME.why_not())
	portals.here = ""
	clock.running = false
	check(PASS_TIME.why_not() != "", "not while the clock's stopped (a race circuit)")
	clock.running = true


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	if game:
		game.hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	else:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	print("RESULT %s (%d failed)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)

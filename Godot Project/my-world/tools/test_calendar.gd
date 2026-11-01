extends SceneTree

# Checks Earth's calendar (scripts/clock.gd): four seasons of four weeks, each starting on a Monday, a new game on
# Friday 19 Autumn, dates and weekdays that agree, weekends and the school holidays, the Autumn Festival only on autumn
# Saturdays (scripts/festival.gd), and the calendar saving, loading, and fitting a save from before it into autumn
# (scripts/game.gd). Then the kids' routines (scripts/routine.gd "weekend" blocks): at school on a weekday morning, out
# round town on a Saturday. Then the lines that depend on the calendar (scripts/dialogue.gd "season", "weekday",
# "weekend", "school_day"), the date on the HUD and the watch, and the Calendar sheet in the Tab menu.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_calendar.gd
#
# Your own save is put aside (under its own name) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.calendar_backup.json"
const EARTH := "res://scenes/earth/earth.tscn"
const KIDS := ["nina_earth", "bruno", "prue", "juniper", "theo", "ozzie"]

var failures := 0
var clock: Node
var game: Node
var dialogue: Node
var F: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	clock = root.get_node("Clock")
	game = root.get_node("Game")
	dialogue = root.get_node("Dialogue")
	F = root.get_node("Festival")
	game._resume = {}
	game.pending_message = ""
	dialogue.reset()
	root.get_node("Quests").reset()
	clock.reset()
	clock.on_earth = true

	# --- The calendar itself ---
	check(clock.date_string() == "Friday 19 Autumn" and clock.year() == 1 and clock.season() == "autumn",
		"a new game starts on Friday 19 Autumn, Year 1 (%s)" % clock.date_string())
	var agree := true
	for d in range(1, 300):
		var i: int = clock.calendar_index(d)
		if clock.weekday(d) != clock.WEEKDAYS[(clock.season_day(d) - 1) % 7]:
			agree = false
		if i != clock.calendar_index(d - 1) + 1 and d > 1:
			agree = false
	check(agree, "every season starts on a Monday, so a date is always the same weekday")
	check(clock.date_string(10) == "Sunday 28 Autumn" and clock.date_string(11) == "Monday 1 Winter",
		"autumn ends on day 10, winter starts on day 11 (%s, %s)" % [clock.date_string(10), clock.date_string(11)])
	check(clock.season(11 + 28) == "spring" and clock.season(11 + 56) == "summer" and clock.season(11 + 84) == "autumn"
		and clock.year(11 + 56) == 2 and clock.date_string(11 + 28) == "Monday 1 Spring",
		"then spring, summer and autumn again, and Year 2 starts in spring")
	check(clock.day_of("winter", 1) == 11 and clock.day_of("autumn", 19) == 1 and clock.day_of("autumn", 18) == 1 + 111,
		"day_of() finds the next date (today counts)")
	check(clock.is_weekend(2) and clock.is_weekend(3) and not clock.is_weekend(4) and not clock.is_weekend(1),
		"Saturday and Sunday are the weekend")
	check(clock.is_school_day(1) and not clock.is_school_day(2) and clock.is_school_day(4), "school on Friday and Monday, not Saturday")
	var winter_hols: int = clock.day_of("winter", 22)
	var spring_break: int = clock.day_of("spring", 8)
	var summer: int = clock.day_of("summer", 3)
	check(clock.school_holiday(winter_hols) == "the winter holidays" and not clock.is_school_day(winter_hols)
		and clock.school_holiday(spring_break) == "spring break" and clock.school_holiday(summer) == "the summer holidays"
		and clock.is_school_day(clock.day_of("spring", 15)), "the winter holidays, spring break and the summer holidays")

	# --- The Autumn Festival: Saturdays in autumn only ---
	check(F.is_festival_day(2) and F.is_festival_day(9) and not F.is_festival_day(16) and not F.is_festival_day(1),
		"the Autumn Festival is on autumn Saturdays (20 and 27 Autumn), not on a winter one")
	check(F.days_until() == 1, "tomorrow's the first festival (%d)" % F.days_until())
	check(F.events_on(11).has("First day of Winter") and F.events_on(2).has("Autumn Festival, 5-10 PM"), "the calendar's events")

	# --- Saving, loading, and saves from before the calendar ---
	clock.day = 30
	clock.calendar_offset = 50
	game.save_game()
	clock.calendar_offset = 0
	game.load_game()
	check(clock.calendar_offset == 50, "the calendar saves and loads")
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	data.erase("calendar_offset")
	data["day"] = 40
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	var before: String = clock.WEEKDAYS[(40 - 1 + clock.CALENDAR_START) % 7]
	game.load_game()
	var sd: int = clock.season_day()
	check(clock.season() == "autumn" and sd >= 15 and sd <= 21 and clock.weekday() == before,
		"a save from before the calendar lands in late autumn and keeps its weekday (%s)" % clock.date_string())

	# --- The kids: school on a weekday, out round town at the weekend ---
	clock.reset()
	clock.on_earth = true
	clock.day = 4                                    # Monday 22 Autumn
	clock.set_earth_time(10 * 60.0, true)
	game.next_spawn = "Entrance"
	change_scene_to_file(EARTH)
	await _frames(8)
	await _physics(6)
	var at_school := []
	for id in KIDS:
		var r: Node = dialogue.routine_of(id)
		if r and r.activity() == "school" and not r.is_present():
			at_school.append(id)
	check(at_school.size() == KIDS.size(), "Monday 10 AM: all the kids are at school %s" % [at_school])
	clock.day = 2                                    # Saturday 20 Autumn
	clock.jumped.emit()
	clock.set_earth_time(10 * 60.0 + 45.0, true)
	await _physics(6)
	var out := []
	for id in KIDS:
		var r: Node = dialogue.routine_of(id)
		if r and r.activity() != "school" and r.is_present():
			out.append(id)
	check(out.size() == KIDS.size(), "Saturday 10:45 AM: no school, everyone's out %s" % [out])
	var nina: Node = dialogue.routine_of("nina_earth")
	check(nina and nina.current_block().get("place", "") == "skate_yard", "Nina's at the skate yard on a Saturday morning")
	var paths := TownPaths.get_shared(TownPaths.EARTH_FILE)
	var places_ok := true
	for id in KIDS:
		var r: Node = dialogue.routine_of(id)
		for b in r.weekend:
			if not paths.has(str(b.place)) or paths.route("gazebo", str(b.place)).is_empty():
				places_ok = false
				print("      %s: can't get to %s" % [id, b.place])
	check(places_ok, "every weekend place is on Earth's paths and can be walked to")
	clock.day = clock.day_of("summer", 3)            # a Wednesday in the summer holidays: weekend blocks again
	clock.jumped.emit()
	await _physics(4)
	check(not clock.is_weekend() and nina.current_block().get("place", "") == "skate_yard",
		"in the summer holidays, a weekday's like a weekend (%s)" % clock.date_string())

	# --- Lines that depend on the calendar ---
	check(dialogue._matches({"season": "summer"}, 1) and not dialogue._matches({"season": ["winter", "spring"]}, 1)
		and dialogue._matches({"weekday": clock.weekday()}, 1) and dialogue._matches({"school_day": false}, 1)
		and not dialogue._matches({"weekend": true}, 1), "dialogue can depend on the season, weekday, weekend and school")
	clock.day = 2
	clock.jumped.emit()
	await _physics(4)
	dialogue.talks["bruno"] = 3
	var lines := " ".join(dialogue._pick("bruno").get("lines", []))
	check(lines.contains("No thchool"), "Bruno on a Saturday morning: no school! (%s)" % lines.left(60))

	# --- The HUD, the watch and the Calendar sheet ---
	await _frames(2)
	var hud := current_scene.find_child("HUD", true, false)
	if hud == null:
		hud = root.find_child("HUD", true, false)
	if hud and hud.has_method("_refresh_clock"):
		hud.call("_refresh_clock")
		check(str(hud.clock_label.text).begins_with("Earth, Saturday 20 Autumn"), "the HUD shows the date (%s)" % hud.clock_label.text.get_slice("\n", 0))
	else:
		check(false, "found the HUD")
	var watch_lines: Array = (load("res://scripts/time_watch.gd") as GDScript).call("lines")
	check(" ".join(watch_lines).contains("Saturday 20 Autumn"), "checking the watch shows the date")
	var menu := root.get_node("PlayerMenu")
	menu.open("calendar")
	await _frames(2)
	var grid := menu._body.find_child("Calendar grid", true, false) as GridContainer
	check(menu.showing("calendar") and grid != null and grid.get_child_count() == 7 + 28, "the Calendar sheet shows a 4-week season")
	var day20 := grid.get_node_or_null("Day 20") if grid else null
	var marked := day20 != null and day20.find_children("*", "Label", true, false).any(
		func(l: Label) -> bool: return l.text.begins_with("Autumn Festival"))
	check(marked, "...with today's Autumn Festival on it")
	check(menu._body.find_child("*", true, false) != null and _text_of(menu._body).contains("No school: it's the weekend!"),
		"...and says there's no school today")
	(menu._body.find_child("Cal next", true, false) as Button).pressed.emit()
	await _frames(2)
	check(_text_of(menu._body).contains("Winter, Year 1"), "Next season shows winter")
	menu.close()
	_end()


func _text_of(n: Node) -> String:
	var out := ""
	for l in n.find_children("*", "Label", true, false):
		out += (l as Label).text + "\n"
	return out


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _end() -> void:
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	_finish()


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)              # (no save before: don't leave the test's one behind)
	quit(1 if failures > 0 else 0)

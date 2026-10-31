extends SceneTree

# Checks the playtest notebook (scripts/playtest.gd) and its report (tools/playtest_report.gd): it's off by default
# and writes nothing then; switched on (Settings > Assist > Playtest notes) it opens a file in the save folder's
# playtest folder and notes First Night steps and how long they took, skips, being stuck, menus, races, requests and
# bails; switched off it stops; it has no way to send anything anywhere; and the report sums it all up.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_playtest.gd
#
# Your own save and settings are put back at the end, and the test's notes are deleted.

const SAVE := "user://save.json"
const BACKUP := "user://save.playtest_backup.json"

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(120.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_put_save_back()
		quit(1))
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var P := root.get_node("Playtest")
	var settings := root.get_node("Settings")
	var quests := root.get_node("Quests")
	var dialogue := root.get_node("Dialogue")
	var keep: bool = settings.playtest
	var fresh: Node = load("res://scripts/settings.gd").new()
	check(fresh.playtest == false, "Playtest notes are off by default")
	fresh.free()
	settings.playtest = false
	settings.apply()
	await _frames(2)
	check(P._file == null and P.events.is_empty(), "...and with them off, nothing's written")

	# --- On ---
	dialogue.reset()
	quests.reset()
	settings.playtest = true
	settings.apply()
	await _frames(2)
	var path: String = P.file_path
	check(P._file != null and path.begins_with("user://playtest/notes_"), "switched on, it opens a notes file in the save folder (%s)" % path)
	dialogue.set_flag("first_night_start")
	quests.check()
	await _frames(2)
	check(_has(P, "step", "evening"), "it notes The First Night's first step")
	P._step_at["first_night"][1] = P._now() - 95.0       # pretend the first step took a while
	quests.skip("first_night")
	await _frames(2)
	check(_has(P, "skip", "evening"), "...a skipped step")
	var done: Array = P.events.filter(func(e: Dictionary) -> bool: return e.what == "step_done")
	check(not done.is_empty() and float(done[0].seconds) >= 94.0, "...and how long the step took (%s s)" % (done[0].seconds if done else "?"))
	P._quiet = P.STUCK - 0.05
	await create_timer(0.2, true, false, true).timeout
	check(P.events.any(func(e: Dictionary) -> bool: return e.what == "stuck"), "3 minutes with nothing new is a stuck moment")
	var stuck_count: int = P.events.filter(func(e: Dictionary) -> bool: return e.what == "stuck").size()
	await create_timer(0.2, true, false, true).timeout
	check(P.events.filter(func(e: Dictionary) -> bool: return e.what == "stuck").size() == stuck_count, "...noted once, not over and over")
	var menu := root.get_node("PlayerMenu")
	menu.open("goals")
	await _frames(3)
	menu.close()
	await _frames(2)
	check(P.events.any(func(e: Dictionary) -> bool: return e.what in ["menu", "menu_open"]), "opening the Tab menu is noted")
	root.get_node("Races").finished.emit("lake_loop", 2)
	P._on_bail()
	await _frames(2)
	check(P.events.any(func(e: Dictionary) -> bool: return e.what == "race_finished"), "races are noted")
	check(P.events.any(func(e: Dictionary) -> bool: return e.what == "bail"), "bails are noted")

	# --- The file and the report ---
	var lines := FileAccess.get_file_as_string(path).split("\n", false)
	check(lines.size() == P.events.size() and JSON.parse_string(lines[0]) is Dictionary,
		"every note is a line in the file (%d)" % lines.size())
	var R := load("res://tools/playtest_report.gd")
	var text: String = R.report(P.events)
	print(text)
	for want in ["PLAYTEST REPORT", "How long each step took", "first_night / evening", "Stuck moments", "Steps skipped: 1",
			"Bails on the board: 1", "lake_loop in place 2", "Menus opened"]:
		check(text.contains(want), "the report has \"%s\"" % want)
	var src := FileAccess.get_file_as_string("res://scripts/playtest.gd")
	check(not src.contains("HTTPRequest") and not src.contains("StreamPeer") and not src.contains("PacketPeer"),
		"nothing leaves the PC: the notebook has no network code")

	# --- Off again ---
	settings.playtest = false
	settings.apply()
	await _frames(2)
	var n: int = P.events.size()
	dialogue.set_flag("anything")
	await _frames(2)
	check(P._file == null and P.events.size() == n, "switched off, it stops writing")

	DirAccess.remove_absolute(path)
	settings.playtest = keep
	settings.apply()
	_put_save_back()
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)


func _has(P: Node, what: String, step: String) -> bool:
	return P.events.any(func(e: Dictionary) -> bool: return e.what == what and str(e.get("step", "")) == step)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _put_save_back() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")

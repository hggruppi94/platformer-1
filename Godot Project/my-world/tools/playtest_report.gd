extends SceneTree

# Turns a playtest notebook (scripts/playtest.gd) into a short summary you can read in a minute.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/playtest_report.gd
#   godot --headless --path "Godot Project/my-world" --script res://tools/playtest_report.gd -- <notes file>
#
# With no file it reads the newest one in the save folder's playtest folder. The summary is printed and also saved
# next to the notes as report_<same name>.txt. It only reads the notes; it never touches the save.

const DIR := "user://playtest/"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var path := args[0] if args.size() > 0 else _newest()
	if path == "" or not FileAccess.file_exists(path):
		print("No playtest notes found. Turn on Settings > Assist > Playtest notes, play, then run this again.")
		quit(1)
		return
	var text := report(_read(path))
	print(text)
	var out := path.get_base_dir().path_join("report_" + path.get_file().get_basename() + ".txt")
	var f := FileAccess.open(out, FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()
		print("\n(Saved to %s)" % ProjectSettings.globalize_path(out))
	quit(0)


func _newest() -> String:
	var d := DirAccess.open(DIR)
	if d == null:
		return ""
	var best := ""
	for f in d.get_files():
		if f.begins_with("notes_") and f.ends_with(".jsonl") and f > best:
			best = f                              # the names start with the date and time, so the biggest is newest
	return DIR + best if best != "" else ""


func _read(path: String) -> Array:
	var out := []
	for line in FileAccess.get_file_as_string(path).split("\n", false):
		var e = JSON.parse_string(line)
		if e is Dictionary:
			out.append(e)
	return out


static func report(events: Array) -> String:
	# The summary, from a list of notes (tools/test_playtest.gd calls this directly)
	var lines: Array[String] = []
	var total := 0.0
	var hero := ""
	var steps: Array = []
	var stuck: Array = []
	var skips: Array = []
	var bails := 0
	var menus := {}
	var races_started := 0
	var races: Array = []
	var requests: Array = []
	var scenes: Array = []
	for e in events:
		total = maxf(total, float(e.get("t", 0.0)))
		match str(e.get("what", "")):
			"notes_on":
				hero = str(e.get("hero", ""))
			"step_done":
				steps.append(e)
			"stuck":
				stuck.append(e)
			"skip":
				skips.append(e)
			"bail":
				bails += 1
			"menu", "menu_open":
				var s := str(e.get("sheet", "?"))
				menus[s] = int(menus.get(s, 0)) + 1
			"pause_menu":
				menus["pause menu"] = int(menus.get("pause menu", 0)) + 1
			"shop":
				var s := "shop: " + str(e.get("stall", "?"))
				menus[s] = int(menus.get(s, 0)) + 1
			"race_started":
				races_started += 1
			"race_finished":
				races.append(e)
			"request_done":
				requests.append(e)
			"scene":
				scenes.append(str(e.get("scene", "")))
	lines.append("PLAYTEST REPORT%s" % (" (%s)" % hero if hero != "" else ""))
	lines.append("Played for %s." % _time(total))
	lines.append("")
	lines.append("How long each step took:")
	if steps.is_empty():
		lines.append("  (no steps finished)")
	for s in steps:
		var slow := "   <- a long one" if float(s.get("seconds", 0)) > 600.0 else ""
		lines.append("  %s / %s: %s%s" % [s.get("quest", ""), s.get("step", ""), _time(float(s.get("seconds", 0))), slow])
	lines.append("")
	lines.append("Stuck moments (3+ minutes with nothing new): %d" % stuck.size())
	for s in stuck:
		var at: Array = s.get("at", [0, 0, 0])
		lines.append("  at %s, in %s near (%d, %d), on %s" % [_time(float(s.t)), s.get("scene", ""), int(at[0]), int(at[2]),
			str(s.get("steps", {})) if not s.get("steps", {}).is_empty() else "free play"])
	lines.append("Steps skipped: %d%s" % [skips.size(), "" if skips.is_empty() else "  (" + ", ".join(skips.map(
		func(s: Dictionary) -> String: return "%s/%s" % [s.get("quest", ""), s.get("step", "")])) + ")"])
	lines.append("Bails on the board: %d" % bails)
	lines.append("Races: %d started, %d finished%s" % [races_started, races.size(), "" if races.is_empty() else "  (" + ", ".join(
		races.map(func(r: Dictionary) -> String: return "%s in place %d" % [r.get("track", ""), int(r.get("place", 0))])) + ")"])
	lines.append("Requests finished: %d" % requests.size())
	var m := []
	for k in menus:
		m.append("%s x%d" % [k, menus[k]])
	lines.append("Menus opened: %s" % (", ".join(m) if not m.is_empty() else "none"))
	lines.append("Worlds visited: %s" % (" > ".join(scenes) if not scenes.is_empty() else "-"))
	return "\n".join(lines)


static func _time(s: float) -> String:
	var m := int(s) / 60
	return "%d min %02d s" % [m, int(s) % 60] if m > 0 else "%d s" % int(s)

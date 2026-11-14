extends SceneTree

# Checks the voice in your mind speaks aloud (Hayden, 14 Nov 2026: "can we give the brain dialogue in your mind a
# voice?", scripts/divine_mind.gd, made by tools/make_mind_voice.py):
#   - every line it can say has its own recording in audio/mind (so a line changed without re-running the tools fails);
#   - lines.txt (the list the recordings are made from) is up to date;
#   - say() speaks each line as it shows, and keeps the words up until it's finished saying them;
#   - in a talk (touching the old oak) its lines are spoken, the first-time line too (recorded without the player's
#     name), the voice stops when the talk moves on, and nobody babbles over it.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_mind_voice.gd
#
# Touches no save.

var failures := 0
var mind: Node
var dialogue: Node


class Talker extends Node3D:
	func begin_talk() -> void:
		pass

	func end_talk() -> void:
		pass


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(120.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		quit(1))
	mind = root.get_node("DivineMind")
	dialogue = root.get_node("Dialogue")
	_run.call_deferred()


func _run() -> void:
	await process_frame
	# --- Every line has its voice ---
	var lines: Array = mind.all_lines()
	var missing: Array = []
	for l in lines:
		if str(l).strip_edges() != "" and not mind.has_voice(str(l)):
			missing.append(str(l))
	check(lines.size() > 30 and missing.is_empty(), "every one of its %d lines has a recording%s" % [lines.size(),
		"" if missing.is_empty() else " (missing %d, e.g. \"%s\": run tools/dump_mind_lines.gd and tools/make_mind_voice.py)" % [missing.size(), missing[0]]])
	var listed := FileAccess.get_file_as_string("res://audio/mind/lines.txt").split("\n", false)
	var stale := lines.filter(func(l) -> bool: return not listed.has(str(l).strip_edges()))
	check(stale.is_empty(), "audio/mind/lines.txt lists them all%s" % ("" if stale.is_empty() else " (not: \"%s\")" % stale[0]))
	check(mind.voice_key("A world needs you!") == "A world needs you!".md5_text().substr(0, 16), "a line's file is named after its words")

	# --- say(): spoken as it shows, the words stay till it's done ---
	mind.clear()
	var before: int = mind.spoken
	mind.say(mind.CRACK_OPENED)
	check(mind.spoken == before + 1 and mind.is_talking(), "a new crack: the voice says its first line aloud")
	var len0: float = (load(mind.voice_path(mind.CRACK_OPENED[0])) as AudioStream).get_length()
	check(len0 > 0.5 and mind._t >= len0, "...and the words stay up till it's said them (%.1f s)" % len0)
	mind._t = 0.01
	await process_frame
	await process_frame
	check(mind._text.text == mind.CRACK_OPENED[1] and mind.spoken == before + 2, "...then it says the next one")
	mind.clear()
	check(not mind.is_talking(), "clearing it stops the voice too")
	mind.say(["A line it was never given."])
	check(mind.speaking() and not mind.is_talking(), "a line with no recording is just shown, quietly")
	mind.clear()

	# --- In a talk ---
	var t := Talker.new()
	root.add_child(t)
	var sound := root.get_node("Soundscape")
	before = mind.spoken
	dialogue.say(t, "Old Oak", ["(The oak hums.)", {"speaker": mind.SPEAKER, "text": mind.OAK_FIRST},
		{"speaker": mind.SPEAKER, "text": mind.HINT_LOOK}, "(It goes quiet.)"])
	check(not mind.is_talking(), "the oak's hum isn't the voice")
	dialogue.call("_next")
	check(mind.spoken == before + 1 and mind.is_talking() and dialogue.raw_line == mind.OAK_FIRST,
		"touching the oak the first time: it says it chose you, out loud")
	check(int(sound.get("_voice_left")) == 0, "...and there's no babble over it")
	check(not dialogue.current_line().contains("{player}"), "...while the words on screen have the hero's name in")
	dialogue.call("_next")
	check(mind.spoken == before + 2 and mind.is_talking(), "then its hint, out loud")
	dialogue.call("_next")
	check(not mind.is_talking(), "the voice stops when the talk moves on")
	dialogue.end()
	check(not mind.is_talking(), "...and when the talk's over")

	print("RESULT %s (%d failures)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(0 if failures == 0 else 1)

extends SceneTree

# Writes every line the voice in your mind can say to res://audio/mind/lines.txt, one a line, exactly as the game
# passes them to DivineMind (with {player} etc. still in). tools/make_mind_voice.py reads that file and makes one
# spoken .ogg for each line (Hayden, 14 Nov 2026: "can we give the brain dialogue in your mind a voice?").
# Run it again after changing any mind line or any quest's goals, then run the Python tool.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/dump_mind_lines.gd

const OUT := "res://audio/mind/lines.txt"

var _frames := 0


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	var mind: Node = root.get_node("DivineMind")
	var lines: Array = mind.call("all_lines")
	var seen := {}
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	for l in lines:
		var s := str(l).strip_edges()
		if s == "" or seen.has(s):
			continue
		seen[s] = true
		f.store_line(s)
	f.close()
	print("dump_mind_lines: %d lines -> %s" % [seen.size(), OUT])
	quit(0)
	return true

extends Node

# Snappy, the Venus flytrap on Bramble's arm, isn't very well trained (Hayden: "snappy needs to snap at the characters
# just for bramble to say sorry"). Put one under Bramble in scenes/town/characters.tscn. Every other time someone
# talks to her, right after her first line he lunges at them and goes SNAP (her "snap" animation), and Bramble says
# sorry before carrying on with what she was saying. The very first meeting is left alone: she introduces him then.

const EVERY := 2                         # snaps on every second conversation
const SORRY := [
	["(Snappy lunges at {player} and goes SNAP!)", "Snappy! No! Sorry, sorry. He's not very well trained yet."],
	["(SNAP! Snappy nips at {player}'s sleeve.)", "Snappy, we don't bite friends! Sorry. He's teething. Do plants teethe?"],
	["(Snappy swings round and snaps at {player}'s nose. Missed!)", "SNAPPY. Sorry! He thinks noses are bugs. We're working on it."],
	["(SNAP SNAP SNAP!)", "Oh, Snappy... Sorry about him. He gets excited when people visit."],
]

var _id := ""
var _armed := false
var _said := 0


func _ready() -> void:
	var talk := get_parent().get_node_or_null("Talk")
	_id = str(talk.get("character_id")) if talk else "bramble"
	Dialogue.started.connect(_on_started)
	Dialogue.line_shown.connect(_on_line)
	Dialogue.finished.connect(func(_who: String) -> void: _armed = false)


func _on_started(id: String) -> void:
	var n: int = Dialogue.talk_count(id)
	_armed = id == _id and n > 1 and n % EVERY == 0


func _on_line(_speaker: String, _text: String) -> void:
	if not _armed:
		return
	_armed = false
	Dialogue.cut_in(SORRY[_said % SORRY.size()])
	_said += 1
	var anim := get_parent().find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim and anim.has_animation("snap"):
		anim.play("snap", 0.1)
		anim.queue("idle")

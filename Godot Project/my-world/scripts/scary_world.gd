extends Node3D

# The Scary World (scenes/scary_world/scary_world.tscn, built by tools/build_scary_world.gd): a small misty wood
# behind the old gate in the far northwest. Spooky, but nothing here can hurt her, and she can always go home: the gate
# behind her, or "Go home to town" in the pause menu.
#
# It's the centipede's home, and the last step of her story, in order (Hayden, 11 Nov 2026):
#   1. the old gate asks yes or no (dialogue/scary_gate.json), but it won't open; a yes is a whisper towards the school
#   2. she's in her corner behind the walls at the castle school, and gulps you down to Dark Hollow (centipede_corner.gd)
#   3. you mend Dark Hollow (dark_hollow.gd); she isn't there, only her note
#   4. then she moves up here, to her hollow log, and the gate opens. First she needs to know you'll stay when she's at
#      her scariest: her boss game (scripts/centipede_boss.gd; she asks first, yes or no, recorded). After it she's
#      your friend for keeps, gets a name, and shares her tricks: wall crawl (scripts/wall_crawl.gd) and her holes
#      round the Void (centipede_holes.gd). Knock on her hollow log and she'll gulp you to Dark Hollow or any hole.
# She's only ever in one place: until Dark Hollow is mended, nobody's home here.

const HOME_SPAWN := "FromScaryWorld"
const HOLES := preload("res://scripts/centipede_holes.gd")
const USE_SPOT := preload("res://scripts/use_spot.gd")
const BOSS := preload("res://scripts/centipede_boss.gd")
const GAME_RECORD := "centipede_scary_game"
const ARENA_MIDDLE := Vector3(0.0, 0.0, -2.0)
const LOG_KNOCK := Vector3(1.6, 0.0, -15.0)              # by the open end of her hollow log (a step from her talk spot)
const IRIS_TIME := 0.6
const SLIDE_TIME := 1.6

var travels := 0                                         # (tests read this)
var gulping := false
var _log_before := 0
var boss: Node3D
var _talk_before := 0


func _ready() -> void:
	Dialogue.set_flag("scary_world_visited")
	var home := HOLES.at_home()
	var c := find_child("Centipede", true, false) as Node3D
	if c and not home:
		c.visible = false                                # not moved in yet: she's still in her corner at the school
		c.process_mode = Node.PROCESS_MODE_DISABLED
		var talk := c.get_node_or_null("Talk") as Area3D
		if talk:
			talk.set_deferred("monitoring", false)
	if home:
		var spot := USE_SPOT.make(LOG_KNOCK, _knock_offer, knock, 1.8, 1.8)
		spot.name = "LogKnock"
		add_child(spot)
		Dialogue.finished.connect(_on_talked)
		Dialogue.started.connect(func(id: String) -> void:
			if id == "centipede":
				_talk_before = Dialogue.choice_log.size())
	var hello := "The Scary World. It's misty and strange... but nothing here can hurt you. The gate behind you goes home, any time."
	if home and not HOLES.gifts_given():
		hello = "The Scary World. Warm violet light by the hollow log... and lots and lots of little feet, pattering about. Somebody's expecting you."
	Game.message.call_deferred(hello)


static func go_home() -> void:
	Game.go(Game.TOWN_SCENE, HOME_SPAWN, "town")


# Knock on her hollow log: she'll take you along her tunnels ------------------------------------------------------------
func _knock_offer() -> String:
	return "knock on the hollow log" if HOLES.gifts_given() and not gulping else ""


func _name() -> String:
	var n := str(Dialogue.names.get("centipede", ""))
	return n if n != "" else "The Centipede"


func knock_lines() -> Array:
	var choice: Array = [{"text": "Dark Hollow, please!", "answer": "dark_hollow", "record": HOLES.RECORD,
		"lines": ["Down we go! Gulp, slide, ptoo!"]}]
	choice.append_array(HOLES.travel_choices("home"))
	choice.append({"text": "Not now, thanks.", "answer": "no", "record": HOLES.RECORD,
		"lines": ["Okay! Knock any time. I'm always in. Well, nearly always."]})
	return ["(Knock knock knock. The hollow log rumbles, and her pale face pops out of the end.)",
		"{player}! Going somewhere? I know all the shortcuts.",
		{"choice": choice}]


func knock() -> void:
	if gulping or Dialogue.is_active():
		return
	_log_before = Dialogue.choice_log.size()
	Juice.blip("thud", 1.5, -6.0)
	var spot := get_node_or_null("LogKnock") as Node3D
	Dialogue.say(spot, _name(), knock_lines(), "centipede_log")


func _on_talked(talk_id: String) -> void:
	if talk_id == "centipede":
		for k in range(_talk_before, Dialogue.choice_log.size()):
			var e: Dictionary = Dialogue.choice_log[k]
			if str(e.get("what", "")) == GAME_RECORD and str(e.get("answer", "")) == "yes":
				start_game.call_deferred()
				return
		return
	if talk_id != "centipede_log":
		return
	for k in range(_log_before, Dialogue.choice_log.size()):
		var e: Dictionary = Dialogue.choice_log[k]
		var a := str(e.get("answer", ""))
		if str(e.get("what", "")) == HOLES.RECORD and a != "no" and a != "home":
			travel.call_deferred(a)
			return


func travel(to: String) -> void:
	# GULP! Then the slide along her tunnels, and out at the other end
	if gulping:
		return
	gulping = true
	travels += 1
	Game.hold_controls(&"gulp", true)
	var overlay := HOLES.gulp_overlay()
	get_tree().root.add_child(overlay)
	overlay.call("close", IRIS_TIME)
	Juice.blip("pop", 0.45, 0.0)
	Juice.blip("thud", 0.7, -4.0)
	Juice.shake(0.2)
	var tw := create_tween()
	tw.tween_interval(IRIS_TIME + 0.4)
	tw.tween_callback(func() -> void:
		overlay.call("slide")
		Juice.blip("whoosh", 0.8, -4.0))
	tw.tween_interval(SLIDE_TIME)
	tw.tween_callback(func() -> void:
		gulping = false
		HOLES.arrive(to, overlay))


# Her boss game ------------------------------------------------------------------------------------------------------
static func fought() -> bool:
	return Dialogue.flags.has("centipede_fought")


func start_game() -> void:
	# She uncurls from round her log, rears up... and the game's on
	if boss != null or fought():
		return
	var c := find_child("Centipede", true, false) as Node3D
	if c:
		c.visible = false
		c.process_mode = Node.PROCESS_MODE_DISABLED
		var talk := c.get_node_or_null("Talk") as Area3D
		if talk:
			talk.set_deferred("monitoring", false)
	boss = BOSS.new() as Node3D
	boss.name = "Centipede Boss"
	add_child(boss)
	boss.global_position = ARENA_MIDDLE
	boss.connect("won", _on_won)
	Audio.play_at("centipede_skitter", ARENA_MIDDLE, 0.0)
	Game.message("She rears right up, eyes glowing... It's only a game! Dodge her charges, and bop her on the head when she's dizzy.")


func _on_won() -> void:
	Dialogue.set_flag("centipede_fought")
	Game.message("She flops over with all her legs waving in the air, giggling. \"You STAYED!\"")
	get_tree().create_timer(2.0).timeout.connect(_back_home)


func _back_home() -> void:
	# Back curled round her log, and straight into being friends for keeps (dialogue/centipede.json)
	if boss:
		boss.queue_free()
		boss = null
	var c := find_child("Centipede", true, false) as Node3D
	if c == null:
		return
	c.visible = true
	c.process_mode = Node.PROCESS_MODE_INHERIT
	var talk := c.get_node_or_null("Talk") as Area3D
	if talk:
		talk.monitoring = true
		if not Dialogue.is_active():
			Dialogue.talk_to(talk)

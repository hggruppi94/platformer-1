extends Node

# Autoload "Sports": the Void's sports corner (Sports & Play, south-east of town) as five little games you can play.
# Hayden (18 Nov 2026): "i want to make the sports fields playable minigames". Plan item 25 asked for skateboard
# basketball where tricks make shots worth more; that's Hoop Shoot.
#
#   hoops   Hoop Shoot, the Basketball Court, with Coach Swish: a minute to score. Press Interact when the meter's in
#           the green and the ball goes in. 2 points, 3 from far out; on your ride in the air x2, mid-trick x3.
#   goals   Goal Kicks, the Soccer Field, against Bonk the goalie: five kicks. A target slides across the goal; press
#           Interact to kick at it. Bonk dives after it, so aim for the corners.
#   tennis  Tennis Rally, the Tennis Court, with Volley: a ring shows where Volley's ball will land. Stand in it and
#           you hit it back by yourself. Three balls; how long a rally can you keep up?
#   climb   Rock Wall Race, the Rock Wall, with Peak: climb to the top and ring the bell, as fast as you can.
#   broom   Sky Sweep, in the sky over the Soccer Field, with Swoosh: the flying sport (Hayden, 18 Nov 2026: "reminiscent
#           of quidditch", our own game, on the Rocket Board, not a broom). Fly, carry the Sparkball through a gold hoop, keep it from Zip and
#           Zap, and catch the Glimmer Moth at the end for 3. (Plan item 25's roller derby was dropped: "more like the
#           races we already have".)
#
# Before writing this we read open-source sports games (Hayden's rule), all MIT: nicolasbize/soccer-course (the ball's
# states, carried, loose and shot; the goalie steering along its goal line towards the ball, clamped between the
# posts; a game manager going reset, kickoff, in play, scored, game over), DotcYuanJia/Godot_BasketballGame (a ball
# moved by our own code, not the physics engine, held, free or shot, a shot worked out from a set flight time and arc
# height so it always lands where it was meant to) and AKM-8byte/FreeKick (real ball flight with drag and spin: far
# too much for a kid's game, so not used). So every ball here flies along a worked-out arc (sport_game.gd arc()):
# the same every time, never stuck in a net, and easy to test.
#
# Each game is a node of its own put on its court while it's played (sport_hoops.gd, sport_goals.gd, sport_tennis.gd,
# sport_climb.gd, sport_broom.gd, all built on sport_game.gd). This autoload puts each host and their talk spot up as
# the town loads (nothing's in the built scene), runs the countdown, the results and the medals, and saves the best
# scores. Each game has a bronze, silver and gold; the first time you reach each one it pays sparkles, and gold in the
# four on the ground wins the Champion Sweatband. The words are short (Hayden's less-reading rule) and nothing waits on
# the clock.

signal finished(game_id: String, score: float)

enum State { IDLE, COUNTDOWN, PLAYING, RESULTS }

const TOWN := "res://scenes/town/town.tscn"
const COUNTDOWN := 3.0
const RESULTS_TIME := 6.0
const HAT := "champion_sweatband"
const ALIENS := "res://models/characters/little_alien_%s.glb"

# Each game: its court (a group in the town), the host and where they stand in the court's own space (facing out to
# the path), and the medals ([name, score, sparkles the first time]). "low": a lower score is better (a time).
const GAMES := {
	"hoops": {"name": "Hoop Shoot", "place": "Basketball Court", "script": "res://scripts/sport_hoops.gd",
		"host": "Coach Swish", "alien": "orange", "at": Vector3(-4.5, 0, 10.4), "face": 0.0,
		"medals": [["Bronze", 8, 3], ["Silver", 18, 5], ["Gold", 30, 8]], "unit": "points",
		"lines": ["HOOP SHOOT! One minute.", "Shoot in the green!", "Tricks on your ride score more!"]},
	"goals": {"name": "Goal Kicks", "place": "Soccer Field", "script": "res://scripts/sport_goals.gd",
		"host": "Bonk", "alien": "green", "at": Vector3(-4.5, 0, 11.9), "face": 0.0,
		"medals": [["Bronze", 2, 3], ["Silver", 3, 5], ["Gold", 5, 8]], "unit": "goals",
		"lines": ["GOAL KICKS! Five kicks.", "Kick when the target's in a corner!", "I'm a good goalie. Woop!"]},
	"tennis": {"name": "Tennis Rally", "place": "Tennis Court", "script": "res://scripts/sport_tennis.gd",
		"host": "Volley", "alien": "yellow", "at": Vector3(-4.5, 0, 8.4), "face": 0.0,
		"medals": [["Bronze", 5, 3], ["Silver", 12, 5], ["Gold", 20, 8]], "unit": "hits",
		"lines": ["TENNIS RALLY! Three balls.", "Stand in the ring.", "You hit it back by yourself!"]},
	"climb": {"name": "Rock Wall Race", "place": "Rock Wall", "script": "res://scripts/sport_climb.gd",
		"host": "Peak", "alien": "purple", "at": Vector3(-6.4, 0, 3.6), "face": 0.0, "low": true,
		"medals": [["Bronze", 45, 3], ["Silver", 25, 5], ["Gold", 15, 8]], "unit": "seconds",
		"lines": ["ROCK WALL RACE!", "Jump up the ledges.", "Ring the bell on top!"]},
	"broom": {"name": "Sky Sweep", "place": "Soccer Field", "script": "res://scripts/sport_broom.gd",
		"host": "Swoosh", "alien": "pink", "at": Vector3(5.5, 0, 11.9), "face": 0.0,
		"medals": [["Bronze", 2, 3], ["Silver", 4, 5], ["Gold", 7, 8]], "unit": "goals",
		"lines": ["SKY SWEEP! Hop on a rocket board!", "Fly the Sparkball through a gold hoop.", "Catch the Glimmer Moth for 3!"]},
}
const SWEATBAND_GAMES := ["hoops", "goals", "tennis", "climb"]   # gold in these four wins the Champion Sweatband
const MEDAL_COLOURS := [Color(0.85, 0.55, 0.3), Color(0.85, 0.9, 1.0), Color(1.0, 0.82, 0.3)]

var best := {}                                    # game id -> best score
var medals := {}                                  # game id -> how many medals won (0..3)

var state := State.IDLE
var game_id := ""
var game: Node3D                                  # the game being played (a sport_game.gd)
var hosts := {}                                   # game id -> its host in this scene
var hud: RaceHud
var meter: Control                                # the shooting meter along the bottom (Hoop Shoot)
var _meter_zone: ColorRect
var _meter_needle: ColorRect
var _meter_hint: Label
var _count := 0.0
var _results := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	hud = RaceHud.new()
	hud.name = "SportsHUD"
	add_child(hud)
	_make_meter()
	get_tree().scene_changed.connect(_on_scene_changed)
	_on_scene_changed.call_deferred()
	Dialogue.finished.connect(_on_talked)


func running() -> bool:
	return state != State.IDLE


func save_data() -> Dictionary:
	return {"best": best.duplicate(), "medals": medals.duplicate()}


func load_data(data: Dictionary) -> void:
	reset()
	var b = data.get("best", {})
	if b is Dictionary:
		for k in b:
			best[str(k)] = float(b[k])
	var m = data.get("medals", {})
	if m is Dictionary:
		for k in m:
			medals[str(k)] = int(m[k])
	_refresh_hosts()


func reset() -> void:
	if running():
		_end()
	best.clear()
	medals.clear()


# -----------------------------------------------------------------------------
# The hosts
# -----------------------------------------------------------------------------
func _on_scene_changed() -> void:
	if running():
		_end()
	hosts.clear()
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path != TOWN:
		return
	for id in GAMES:
		var place := place_of(id)
		if place:
			hosts[id] = _make_host(id, place)
	_refresh_hosts()


func place_of(id: String) -> Node3D:
	var scene := get_tree().current_scene
	if scene == null or not GAMES.has(id):
		return null
	return scene.find_child(str(GAMES[id].place), true, false) as Node3D


func _make_host(id: String, place: Node3D) -> Node3D:
	# A little alien in a sweatband and a whistle, with their name and best score over them, and a spot to talk to
	var g: Dictionary = GAMES[id]
	var h := Node3D.new()
	h.name = "Sports Host"
	h.set_meta("game_id", id)
	h.add_to_group("sports_host")
	place.add_child(h)
	h.position = g.at
	h.rotation.y = float(g.face)
	var model := (load(ALIENS % g.alien) as PackedScene).instantiate() as Node3D
	model.name = "Model"
	model.scale = Vector3.ONE * 1.9
	h.add_child(model)
	LittleAliens.vary_snout(model)
	var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim and anim.has_animation("idle"):
		anim.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
		anim.play("idle")
	var band := TorusMesh.new()                               # a sweatband in the game's colour, and a whistle
	band.inner_radius = 0.2
	band.outer_radius = 0.26
	SportGame.mesh_on(h, band, Vector3(0, 0.93, 0), SportGame.mat(_colour(id), 0.3)).scale = Vector3(1, 0.6, 1)
	var whistle := SphereMesh.new()
	whistle.radius = 0.05
	whistle.height = 0.1
	SportGame.mesh_on(h, whistle, Vector3(0.0, 0.62, 0.24), SportGame.mat(Color(1.0, 0.82, 0.35), 0.3, 0.8))
	var name_l := SportGame.label_on(h, str(g.host), 26, Vector3(0, 1.95, 0))
	name_l.name = "Name"
	name_l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var best_l := SportGame.label_on(h, "", 20, Vector3(0, 2.3, 0))
	best_l.name = "Best"
	best_l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.35
	shape.height = 1.4
	cs.shape = shape
	cs.position.y = 0.7
	body.add_child(cs)
	h.add_child(body)
	var spot := (load("res://scripts/sport_spot.gd") as GDScript).new() as Area3D
	spot.name = "Sports Talk"
	spot.set("verb", "play " + str(g.name))
	h.add_child(spot)
	return h


func _colour(id: String) -> Color:
	return {"hoops": Color(1.0, 0.5, 0.2), "goals": Color(0.45, 0.9, 0.45), "tennis": Color(1.0, 0.9, 0.3),
		"climb": Color(0.7, 0.5, 1.0), "broom": Color(1.0, 0.5, 0.85)}.get(id, Color.WHITE)


func _refresh_hosts() -> void:
	for id in hosts:
		var h := hosts[id] as Node3D
		if not is_instance_valid(h):
			continue
		var l := h.get_node_or_null("Best") as Label3D
		if l:
			var got := int(medals.get(id, 0))
			var stars := "" if got == 0 else " " + "★".repeat(got)
			l.text = ("Best: %s%s" % [show_score(id, float(best[id])), stars]) if best.has(id) else str(GAMES[id].name)
			l.modulate = MEDAL_COLOURS[got - 1] if got > 0 else Color(1, 0.95, 0.75)


func show_score(id: String, s: float) -> String:
	if GAMES[id].get("low", false):
		return "%.1f s" % s
	return str(int(s))


# -----------------------------------------------------------------------------
# Talking to a host
# -----------------------------------------------------------------------------
func talk(spot: Node3D) -> void:
	if running() or Races.racing() or SkateRuns.running():
		return
	var id := str(spot.get_parent().get_meta("game_id", ""))
	if GAMES.has(id):
		# The spot is the talker (it has begin_talk and end_talk); the host's own body is a plain Node3D, and handing
		# that over stopped say() half way with the player's controls locked, which froze the game.
		Dialogue.say(spot, str(GAMES[id].host), lines(id), "sports")


func lines(id: String) -> Array:
	# Three short lines and the choice (Hayden: lots less reading), then the medals as one short line
	var g: Dictionary = GAMES[id]
	var out: Array = g.lines.duplicate()
	var m: Array = g.medals
	if g.get("low", false):
		out.append("Gold: under %d seconds!" % int(m[2][1]))
	else:
		out.append("Gold: %d %s!" % [int(m[2][1]), g.unit])
	out.append({"choice": [{"text": "Let's play!", "set": "sports_go_" + id}, {"text": "Not now."}]})
	return out


func _on_talked(id: String) -> void:
	if id != "sports":
		return
	for f in Dialogue.flags.keys():
		if str(f).begins_with("sports_go_"):
			Dialogue.flags.erase(f)
			start.call_deferred(str(f).trim_prefix("sports_go_"))
			return


# -----------------------------------------------------------------------------
# A game
# -----------------------------------------------------------------------------
func player() -> CharacterBody3D:
	return get_tree().get_first_node_in_group("player") as CharacterBody3D


func start(id: String) -> bool:
	var p := player()
	var place := place_of(id)
	if running() or Races.racing() or SkateRuns.running() or p == null or place == null or not GAMES.has(id):
		return false
	game_id = id
	game = (load(str(GAMES[id].script)) as GDScript).new() as Node3D
	game.name = "Sports Game"
	game.set("sports", self)
	game.set("p", p)
	game.set("host", hosts.get(id))
	place.add_child(game)
	game.call("setup")
	state = State.COUNTDOWN
	_count = COUNTDOWN
	Game.hold_controls(&"sports", true, p)
	p.velocity = Vector3.ZERO
	hud.clear()
	hud.lap_label.text = str(GAMES[id].name).to_upper()
	_status()
	hud.shout("3", Color(1.0, 0.85, 0.3), 0.5)
	Audio.play("ui_move")
	return true


func _unhandled_input(event: InputEvent) -> void:
	# While a game's on, Interact is the game's (shoot, kick): it never starts a talk with someone nearby
	if state == State.PLAYING and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if is_instance_valid(game):
			game.call("action")


func _physics_process(delta: float) -> void:
	match state:
		State.COUNTDOWN:
			_countdown(delta)
		State.PLAYING:
			if Races.racing() or not is_instance_valid(game) or player() == null:
				_end()
				return
			game.call("tick", delta)
			_status()
		State.RESULTS:
			_results -= delta
			if _results <= 0.0:
				_end()


func _countdown(delta: float) -> void:
	var p := player()
	if p == null or not is_instance_valid(game):
		_end()
		return
	Game.hold_controls(&"sports", true, p)
	var before := ceili(_count)
	_count -= delta
	var now := ceili(_count)
	if now != before and now > 0:
		hud.shout(str(now), Color(1.0, 0.85, 0.3), 0.5)
		Audio.play("ui_move")
		Juice.blip("tick", 1.0, -6.0)
	if _count <= 0.0:
		state = State.PLAYING
		Game.hold_controls(&"sports", bool(game.get("hold")), p)  # (the kicks keep you on the spot)
		hud.shout("GO!", Color(0.5, 1.0, 0.6), 0.5)
		Audio.play("level_up")
		game.call("go")


func _status() -> void:
	if not is_instance_valid(game):
		return
	var s: Array = game.call("status")
	hud.place_label.text = str(s[0])
	hud.place_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	hud.time_label.text = str(s[1])


func shout(text: String, colour := Color(1.0, 0.85, 0.3), hold := 0.6) -> void:
	hud.shout(text, colour, hold)


func over(score: float, headline: String) -> void:
	# The game's done (the time's up, the last kick, the last ball, the bell): the results and the medals
	if state != State.PLAYING:
		return
	var p := player()
	if p:
		Game.hold_controls(&"sports", false, p)
	var g: Dictionary = GAMES[game_id]
	var low := bool(g.get("low", false))
	var has_old := best.has(game_id)
	var old := float(best.get(game_id, 0.0))
	var counts := score >= 0.0                                  # (a climb that never rang the bell has no time)
	var new_best := counts and (not has_old or (score < old if low else score > old))
	if new_best:
		best[game_id] = score
	var had := int(medals.get(game_id, 0))
	var now := 0
	if counts:
		for k in g.medals.size():
			var need := float(g.medals[k][1])
			if (score <= need) if low else (score >= need):
				now = k + 1
	var pay := 0
	var text := "%s\n\n" % headline
	text += ("%s %s\n" % [show_score(game_id, score), "" if low else str(g.unit)]) if counts else "No time.\n"
	if new_best and has_old:
		text += "New best!\n"
	elif has_old and not new_best:
		text += "Best: %s\n" % show_score(game_id, old)
	for k in g.medals.size():
		var m: Array = g.medals[k]
		var need := ("%d s" % int(m[1])) if low else str(int(m[1]))
		if k < now:
			text += "\n★ %s" % m[0]
			if k >= had:
				pay += int(m[2])
				text += "  ✦ %d" % int(m[2])
		else:
			text += "\n○ %s: %s" % [m[0], need]
	if now > had:
		medals[game_id] = now
	if pay > 0:
		Game.add_sparkles(pay, "%s medal!" % str(g.medals[now - 1][0]))
		Juice.blip("sparkle")
	if _all_gold() and not Game.has_item("shop:" + HAT):
		Game.items.append("shop:" + HAT)
		text += "\n\nGold in all four!\nChampion Sweatband!"
		Game.message("You won the Champion Sweatband!")
	hud.show_results(text)
	hud.shout(headline, Color(1.0, 0.85, 0.3), 0.8)
	state = State.RESULTS
	_results = RESULTS_TIME
	show_meter(false)
	_refresh_hosts()
	finished.emit(game_id, score)


func _all_gold() -> bool:
	for id in SWEATBAND_GAMES:
		if int(medals.get(id, 0)) < 3:
			return false
	return true


func _end() -> void:
	var p := player()
	if p:
		Game.hold_controls(&"sports", false, p)
	if is_instance_valid(game):
		game.call("teardown")
		game.queue_free()
	game = null
	state = State.IDLE
	game_id = ""
	hud.clear()
	show_meter(false)


# -----------------------------------------------------------------------------
# The shooting meter (Hoop Shoot): a bar along the bottom, a green zone and a needle that slides up and back
# -----------------------------------------------------------------------------
func _make_meter() -> void:
	var layer := CanvasLayer.new()
	layer.name = "SportsMeter"
	layer.layer = 5
	add_child(layer)
	meter = Control.new()
	meter.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	meter.position = Vector2(-190, -120)
	meter.size = Vector2(380, 70)
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(meter)
	var back := Panel.new()
	back.size = Vector2(380, 34)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.1, 0.25, 0.85)
	sb.set_corner_radius_all(12)
	sb.border_color = Color(1.0, 0.85, 0.4)
	sb.set_border_width_all(3)
	back.add_theme_stylebox_override("panel", sb)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.add_child(back)
	_meter_zone = ColorRect.new()
	_meter_zone.color = Color(0.4, 1.0, 0.5, 0.9)
	_meter_zone.position = Vector2(0, 5)
	_meter_zone.size = Vector2(60, 24)
	_meter_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.add_child(_meter_zone)
	_meter_needle = ColorRect.new()
	_meter_needle.color = Color(1, 1, 1)
	_meter_needle.size = Vector2(8, 40)
	_meter_needle.position = Vector2(0, -3)
	_meter_needle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.add_child(_meter_needle)
	_meter_hint = Label.new()
	_meter_hint.position = Vector2(0, 38)
	_meter_hint.size = Vector2(380, 30)
	_meter_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_meter_hint.add_theme_font_size_override("font_size", 22)
	_meter_hint.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.2))
	_meter_hint.add_theme_constant_override("outline_size", 8)
	meter.add_child(_meter_hint)
	meter.visible = false


func show_meter(on: bool, hint := "") -> void:
	if meter:
		meter.visible = on
		_meter_hint.text = hint


func set_meter(value: float, lo: float, hi: float) -> void:
	# value, lo and hi run 0..1 along the bar
	var w := 380.0
	_meter_zone.position.x = 6.0 + lo * (w - 12.0)
	_meter_zone.size.x = maxf(4.0, (hi - lo) * (w - 12.0))
	_meter_needle.position.x = 6.0 + value * (w - 12.0) - 4.0

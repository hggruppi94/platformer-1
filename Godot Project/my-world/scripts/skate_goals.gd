extends Node3D

# The Skate Park's goals, like Tony Hawk's: collect the letters S-K-A-T-E hidden round the park, land a big combo,
# grind and manual for a long time, land a 540, do your special, and rack up a big score here. Each one pays sparkles
# once (scripts/game.gd), and the board by the park ticks them off. Done goals and collected letters are Dialogue
# flags ("skate_goal_<id>", "skate_letter_<letter>"), so they're saved with the game like everything else.
#
# tools/build_town.gd puts this on the Skate Park, with the letters as Marker3D children ("Letter S"...) and the board.
# The tricks and scores come from the skater (scenes/player/skate_tricks.gd), and only count in the park.

const RADIUS := 18.0                  # how far from the middle counts as in the park
const LETTERS := ["S", "K", "A", "T", "E"]
const GOALS := [
	{"id": "letters", "text": "Collect S-K-A-T-E", "sparkles": 5},
	{"id": "combo", "text": "Land a 2,500 point combo", "sparkles": 5},
	{"id": "grind", "text": "Grind for 3 seconds", "sparkles": 3},
	{"id": "manual", "text": "Manual for 3 seconds", "sparkles": 3},
	{"id": "spin", "text": "Land a 540 spin", "sparkles": 3},
	{"id": "special", "text": "Do your special trick", "sparkles": 5},
	{"id": "score", "text": "Score 15,000 here", "sparkles": 8},
]

var park_score := 0                   # everything she's scored here since she arrived in town
var _player: Node
var _letters := {}                    # letter -> its Area3D
var _board: Label3D
var _t := 0.0


func _ready() -> void:
	_board = find_child("Goals", true, false) as Label3D
	for l in LETTERS:
		var m := get_node_or_null("Letter " + l) as Node3D
		if m:
			_letters[l] = _make_letter(l, m)
	_refresh()
	_hook_up.call_deferred()


func _hook_up() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player == null or _player.get("skate") == null:
		return
	var tricks: SkateTricks = _player.skate.tricks
	tricks.banked.connect(_on_banked)
	tricks.live_done.connect(_on_live_done)


func _process(delta: float) -> void:
	# The letters bob up and down
	_t += delta
	for l in _letters:
		var a: Area3D = _letters[l]
		if a.visible:
			(a.get_node("Look") as Node3D).position.y = sin(_t * 2.0 + LETTERS.find(l)) * 0.15


func is_done(id: String) -> bool:
	return Dialogue.flags.has("skate_goal_" + id)


func in_park() -> bool:
	if _player == null:
		return false
	var d: Vector3 = (_player as Node3D).global_position - global_position
	return Vector2(d.x, d.z).length() < RADIUS


func complete(id: String) -> void:
	if is_done(id):
		return
	for g in GOALS:
		if g.id == id:
			Dialogue.set_flag("skate_goal_" + id)
			Game.add_sparkles(int(g.sparkles), "Skate goal: %s!" % g.text)
			Audio.play("level_up", -4.0, 0.0)
	_refresh()


func _on_banked(points: int, names: String) -> void:
	if not in_park():
		return
	park_score += points
	var tricks: Array = Array(names.split(" + "))
	if points >= 2500:
		complete("combo")
	for spin in ["540", "720", "900", "1080", "1260"]:
		if spin in tricks:
			complete("spin")
	if _player and String(_player.skate.ride.tricks.special[0]) in tricks:
		complete("special")
	if park_score >= 15000:
		complete("score")
	_refresh()


func _on_live_done(name: String, seconds: float) -> void:
	if not in_park() or seconds < 3.0:
		return
	var ride: Dictionary = _player.skate.ride
	complete("manual" if name == ride.tricks.manual or name == ride.tricks.nose_manual else "grind")


# -----------------------------------------------------------------------------
# The letters
# -----------------------------------------------------------------------------
func _make_letter(l: String, at: Node3D) -> Area3D:
	var a := Area3D.new()
	a.name = "Pickup " + l
	a.monitorable = false
	add_child(a)
	a.position = at.position
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.0
	cs.shape = sphere
	a.add_child(cs)
	var look := Node3D.new()
	look.name = "Look"
	a.add_child(look)
	var label := Label3D.new()
	label.text = l
	label.font_size = 160
	label.pixel_size = 0.006
	label.outline_size = 24
	label.modulate = Color(1.0, 0.85, 0.3)
	label.outline_modulate = Color(0.45, 0.1, 0.4)
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y      # always facing her, so it reads the right way round
	look.add_child(label)
	a.visible = not Dialogue.flags.has("skate_letter_" + l) and not is_done("letters")
	a.body_entered.connect(func(body: Node3D) -> void: _on_letter(l, a, body))
	return a


func _on_letter(l: String, a: Area3D, body: Node3D) -> void:
	# Only on the board, like in Tony Hawk's: walking up to them doesn't count
	if not a.visible or not body.is_in_group("player") or not Game.riding:
		return
	a.visible = false
	Dialogue.set_flag("skate_letter_" + l)
	Audio.play("pickup", -3.0, 0.0)
	Fx.burst(get_tree().current_scene, a.global_position, Color(1.0, 0.85, 0.3), 12, 0.06, 3.0, -2.0, 0.6)
	var got := 0
	for k in LETTERS:
		if Dialogue.flags.has("skate_letter_" + k):
			got += 1
	if got == LETTERS.size():
		complete("letters")
	else:
		Game.message("%s! (%d of 5 letters)" % [l, got])
	_refresh()


func _refresh() -> void:
	if _board == null:
		return
	var lines: PackedStringArray = ["SKATE PARK GOALS", ""]
	for g in GOALS:
		var mark := "★" if is_done(g.id) else "•"
		var extra := ""
		if g.id == "letters" and not is_done("letters"):
			var have := ""
			for l in LETTERS:
				have += l if Dialogue.flags.has("skate_letter_" + l) else "_"
			extra = "  " + have
		elif g.id == "score" and not is_done("score"):
			extra = "  (%d)" % park_score
		lines.append("%s %s%s   ✦ %d" % [mark, g.text, extra, g.sparkles])
	_board.text = "\n".join(lines)

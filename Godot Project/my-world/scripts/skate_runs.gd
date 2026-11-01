extends Node

# Autoload "SkateRuns": timed skate runs, like Tony Hawk's two-minute sessions. At each skate park there's a Run Clock
# (Galaxity's Skate Park and Stars Hollow's Hollow Skate Yard: RUNS). Interact with it and say go: a 3-2-1, then two
# minutes to score as much as you can, anywhere you like. Every combo you land in the two minutes counts (gaps too:
# scripts/skate_gaps.gd), and when the clock runs out the combo you're in the middle of still counts if you land it.
# Then the results: your score, your best, and the medals. Each park has a bronze, silver and gold score; the first
# time you reach each one it pays sparkles. Best scores and medals are saved with the game (scripts/game.gd,
# "skate_runs").
#
# The Run Clock (a post with a big clock face) is put up at play time, so the scenes weren't rebuilt. While a run is on
# its time and score are across the top of the screen (a RaceHud, scripts/race_hud.gd, the same look as a race).
# Stepping off your ride, starting a race or leaving the place ends the run with no harm done.

signal finished(run_id: String, score: int)

enum State { IDLE, COUNTDOWN, RUNNING, LAST_COMBO, RESULTS }

const EARTH := "res://scenes/earth/earth.tscn"
const TOWN := "res://scenes/town/town.tscn"
const COUNTDOWN := 3.0
const RESULTS_TIME := 7.0
const LAST_COMBO := 8.0                           # after the buzzer, at most this long to land the combo you're in

# Each run: its scene, the skate park it's at, where the Run Clock stands in the park's frame, how long, and the
# medals (score, sparkles the first time)
const RUNS := {
	"skate_park": {"name": "Skate Park Run", "scene": TOWN, "park": "Skate Park", "at": Vector3(0, 0, 17.0), "face": PI,
		"time": 120.0, "medals": [["Bronze", 5000, 3], ["Silver", 15000, 5], ["Gold", 35000, 8]]},
	"skate_yard": {"name": "Skate Yard Run", "scene": EARTH, "park": "Hollow Skate Yard", "at": Vector3(-17.5, 0.2, -16.0),
		"face": 0.83, "time": 120.0, "medals": [["Bronze", 6000, 3], ["Silver", 18000, 5], ["Gold", 40000, 8]]},
}
const MEDAL_COLOURS := [Color(0.85, 0.55, 0.3), Color(0.85, 0.9, 1.0), Color(1.0, 0.82, 0.3)]

var best := {}                                    # run id -> best score
var medals := {}                                  # run id -> how many medals won (0..3)

var state := State.IDLE
var run_id := ""
var left := 0.0                                   # seconds left in the run
var score := 0
var gaps := 0                                     # gaps landed in this run
var hud: RaceHud
var clocks := {}                                  # run id -> its Run Clock in this scene
var _count := 0.0
var _results := 0.0
var _last := 0.0
var _tricks: SkateTricks


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	hud = RaceHud.new()
	hud.name = "RunHUD"
	add_child(hud)
	get_tree().scene_changed.connect(_on_scene_changed)
	_on_scene_changed.call_deferred()
	Dialogue.finished.connect(_on_talked)
	Gaps.landed_gap.connect(func(_id: String, _pts: int) -> void:
		if state == State.RUNNING or state == State.LAST_COMBO:
			gaps += 1)


func running() -> bool:
	return state != State.IDLE


func save_data() -> Dictionary:
	return {"best": best.duplicate(), "medals": medals.duplicate()}


func load_data(data: Dictionary) -> void:
	reset()
	for key in ["best", "medals"]:
		var d = data.get(key, {})
		if d is Dictionary:
			for k in d:
				(best if key == "best" else medals)[str(k)] = int(d[k])
	_refresh_clocks()


func reset() -> void:
	if running():
		_end()
	best.clear()
	medals.clear()


# -----------------------------------------------------------------------------
# The Run Clocks
# -----------------------------------------------------------------------------
func _on_scene_changed() -> void:
	if running():
		_end()
	clocks.clear()
	var scene := get_tree().current_scene
	if scene == null:
		return
	for id in RUNS:
		var r: Dictionary = RUNS[id]
		if r.scene != scene.scene_file_path:
			continue
		var park := scene.find_child(str(r.park), true, false) as Node3D
		if park == null:
			continue
		clocks[id] = _make_clock(id, park)
	_refresh_clocks()


func _make_clock(id: String, park: Node3D) -> Node3D:
	# A tall lilac post with a big round clock face on top and a sign under it, and a spot to talk to
	var r: Dictionary = RUNS[id]
	var c := Node3D.new()
	c.name = "Run Clock"
	c.set_meta("run_id", id)
	park.add_child(c)
	c.position = r.at
	c.rotation.y = float(r.face)
	var post := CylinderMesh.new()
	post.top_radius = 0.09
	post.bottom_radius = 0.12
	post.height = 2.6
	_mesh(c, post, Vector3(0, 1.3, 0), _mat(Color(0.62, 0.5, 0.95)))
	var face := CylinderMesh.new()
	face.top_radius = 0.75
	face.bottom_radius = 0.75
	face.height = 0.16
	var f := _mesh(c, face, Vector3(0, 3.2, 0), _mat(Color(0.98, 0.95, 0.85), 0.3))
	f.rotation.x = PI / 2.0
	var rim := TorusMesh.new()
	rim.inner_radius = 0.72
	rim.outer_radius = 0.84
	var rm := _mesh(c, rim, Vector3(0, 3.2, 0), _mat(Color(1.0, 0.82, 0.35), 0.4))
	rm.rotation.x = PI / 2.0
	for k in 12:                                              # the hour marks
		var a := TAU * k / 12.0
		var mark := BoxMesh.new()
		mark.size = Vector3(0.05, 0.14 if k % 3 == 0 else 0.08, 0.04)
		var m := _mesh(c, mark, Vector3(sin(a) * 0.6, 3.2 + cos(a) * 0.6, 0.1), _mat(Color(0.22, 0.16, 0.34)))
		m.rotation.z = -a
	var hand := BoxMesh.new()
	hand.size = Vector3(0.06, 0.55, 0.03)
	var h := Node3D.new()
	h.name = "Hand"
	h.position = Vector3(0, 3.2, 0.12)
	c.add_child(h)
	_mesh(h, hand, Vector3(0, 0.25, 0), _mat(Color(1.0, 0.45, 0.7), 0.5))
	var sign_m := BoxMesh.new()
	sign_m.size = Vector3(1.9, 0.75, 0.08)
	_mesh(c, sign_m, Vector3(0, 2.05, 0.05), _mat(Color(0.22, 0.16, 0.34)))
	var label := _label3d(c, "SKATE RUN\n2:00", 30, Vector3(0, 2.05, 0.1))
	label.name = "Sign"
	var best_l := _label3d(c, "", 22, Vector3(0, 4.25, 0))
	best_l.name = "Best"
	best_l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.15
	shape.height = 2.6
	cs.shape = shape
	cs.position.y = 1.3
	body.add_child(cs)
	c.add_child(body)
	var spot := (load("res://scripts/run_spot.gd") as GDScript).new() as Area3D
	spot.name = "Run Talk"
	c.add_child(spot)
	return c


func _refresh_clocks() -> void:
	for id in clocks:
		var c := clocks[id] as Node3D
		if not is_instance_valid(c):
			continue
		var l := c.get_node_or_null("Best") as Label3D
		if l:
			var got := int(medals.get(id, 0))
			l.text = ("Best: %s" % _num(int(best[id])) if best.has(id) else "Two minutes. How much can you score?") + \
				("\n" + " ".join(range(got).map(func(k: int) -> String: return "★ " + str(RUNS[id].medals[k][0]))) if got > 0 else "")


func _process(delta: float) -> void:
	# The clock's hand sweeps round while a run is on
	if state == State.RUNNING and clocks.has(run_id) and is_instance_valid(clocks[run_id]):
		var hand := (clocks[run_id] as Node3D).get_node_or_null("Hand") as Node3D
		if hand:
			hand.rotation.z = -TAU * (1.0 - left / float(RUNS[run_id].time))


# -----------------------------------------------------------------------------
# Talking to the Run Clock
# -----------------------------------------------------------------------------
func talk(spot: Node3D) -> void:
	if running() or Races.racing():
		return
	var id := str(spot.get_parent().get_meta("run_id", ""))
	if not RUNS.has(id):
		return
	Dialogue.say(spot, "Run Clock", lines(id), "skate_run")


func lines(id: String) -> Array:
	var r: Dictionary = RUNS[id]
	if not Game.has_item("skateboard"):
		return ["SKATE RUN: two minutes to score as much as you can!",
			"You'll need something to ride first. There's a skateboard waiting at Galaxity's Skate Park."]
	var m: Array = r.medals
	var out: Array = ["SKATE RUN: you've got %d seconds to score as much as you can, anywhere you like. Combos count, gaps count, and the combo you're in when the buzzer goes counts if you land it!" % int(r.time),
		"Bronze %s (✦ %d), Silver %s (✦ %d), Gold %s (✦ %d)." % [_num(m[0][1]), m[0][2], _num(m[1][1]), m[1][2], _num(m[2][1]), m[2][2]]]
	if best.has(id):
		out.append("Your best here is %s." % _num(int(best[id])))
	out.append({"choice": [{"text": "Start the run!", "set": "skate_run_go_" + id}, {"text": "Not right now."}]})
	return out


func _on_talked(id: String) -> void:
	if id != "skate_run":
		return
	for f in Dialogue.flags.keys():
		if str(f).begins_with("skate_run_go_"):
			Dialogue.flags.erase(f)
			start.call_deferred(str(f).trim_prefix("skate_run_go_"))
			return


# -----------------------------------------------------------------------------
# A run
# -----------------------------------------------------------------------------
func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func start(id: String) -> bool:
	var p := _player()
	if running() or Races.racing() or not clocks.has(id) or p == null or not Game.has_item("skateboard"):
		return false
	if not Game.riding:
		Game.riding = true
		Game.equipment_changed.emit()
	var skate = p.get("skate")
	if skate == null:
		return false
	_tricks = skate.tricks
	_tricks.lose()
	if not _tricks.banked.is_connected(_on_banked):
		_tricks.banked.connect(_on_banked)
	run_id = id
	left = float(RUNS[id].time)
	score = 0
	gaps = 0
	state = State.COUNTDOWN
	_count = COUNTDOWN
	p.set("input_locked", true)
	p.set("velocity", Vector3.ZERO)
	hud.clear()
	_status()
	hud.shout("3", Color(1.0, 0.85, 0.3), 0.5)
	Audio.play("ui_move")
	return true


func _on_banked(points: int, _names: String) -> void:
	if state == State.RUNNING or state == State.LAST_COMBO:
		score += points
		_status()
		if state == State.LAST_COMBO:
			_finish()


func _physics_process(delta: float) -> void:
	match state:
		State.COUNTDOWN:
			_countdown(delta)
		State.RUNNING:
			_run(delta)
		State.LAST_COMBO:
			_last -= delta
			if not _still_riding():
				return
			if _tricks == null or not _tricks.is_active() or _last <= 0.0:
				_finish()                             # landed and paid, lost in a bail, or took too long
		State.RESULTS:
			_results -= delta
			if _results <= 0.0:
				_end()


func _countdown(delta: float) -> void:
	var p := _player()
	if p == null:
		_end()
		return
	p.set("velocity", Vector3.ZERO)
	p.set("input_locked", true)
	var before := ceili(_count)
	_count -= delta
	var now := ceili(_count)
	if now != before and now > 0:
		hud.shout(str(now), Color(1.0, 0.85, 0.3), 0.5)
		Audio.play("ui_move")
		Juice.blip("tick", 1.0, -6.0)
	if _count <= 0.0:
		state = State.RUNNING
		p.set("input_locked", false)
		hud.shout("GO!", Color(0.5, 1.0, 0.6), 0.5)
		Audio.play("level_up")
		Juice.shake(0.15)


func _still_riding() -> bool:
	if Game.riding and not Races.racing():
		return true
	Game.message("You stepped off your ride, so the skate run's off. The Run Clock's there when you want another go!" \
		if not Races.racing() else "A race! The skate run's off.")
	_end()
	return false


func _run(delta: float) -> void:
	if not _still_riding():
		return
	var before := ceili(left)
	left -= delta
	if ceili(left) != before and ceili(left) <= 10 and left > 0.0:
		Juice.blip("tick", 1.2, -8.0)                 # the last ten seconds tick
	_status()
	if left <= 0.0:
		left = 0.0
		hud.shout("TIME!", Color(1.0, 0.55, 0.6), 0.8)
		Audio.play("level_up", -4.0)
		if _tricks and _tricks.is_active():
			state = State.LAST_COMBO                  # still in a combo: land it and it counts
			_last = LAST_COMBO
			_status()
		else:
			_finish()


func _status() -> void:
	hud.lap_label.text = str(RUNS[run_id].name).to_upper() if run_id != "" else ""
	hud.place_label.text = "%d:%02d" % [int(ceili(left)) / 60, int(ceili(left)) % 60] if state != State.LAST_COMBO else "Land it!"
	hud.place_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.6) if left <= 10.0 else Color(1.0, 0.85, 0.3))
	hud.time_label.text = "Score %s" % _num(score)


func _finish() -> void:
	var r: Dictionary = RUNS[run_id]
	var old := int(best.get(run_id, -1))
	var new_best := score > old
	if new_best:
		best[run_id] = score
	var had := int(medals.get(run_id, 0))
	var now := 0
	for k in r.medals.size():
		if score >= int(r.medals[k][1]):
			now = k + 1
	var pay := 0
	var text := "%s\n\nScore: %s\n" % ["TIME'S UP!", _num(score)]
	if gaps > 0:
		text += "Gaps landed: %d\n" % gaps
	if new_best and old >= 0:
		text += "New best!\n"
	elif not new_best:
		text += "Best: %s\n" % _num(old)
	for k in r.medals.size():
		var m: Array = r.medals[k]
		if k < now:
			text += "\n★ %s! (%s)" % [m[0], _num(m[1])]
			if k >= had:
				pay += int(m[2])
				text += "  ✦ %d" % int(m[2])
		else:
			text += "\n○ %s: %s" % [m[0], _num(m[1])]
	if now > had:
		medals[run_id] = now
	if pay > 0:
		var won: Array = []
		for k in range(had, now):
			won.append(str(r.medals[k][0]))
		Game.add_sparkles(pay, "%s medal%s in the %s!" % [" and ".join(won), "" if won.size() == 1 else "s", r.name])
	hud.show_results(text)
	hud.shout("TIME'S UP!", Color(1.0, 0.85, 0.3), 0.8)
	state = State.RESULTS
	_results = RESULTS_TIME
	_refresh_clocks()
	finished.emit(run_id, score)


func _end() -> void:
	var p := _player()
	if p and state == State.COUNTDOWN:
		p.set("input_locked", false)
	state = State.IDLE
	run_id = ""
	hud.clear()


# -----------------------------------------------------------------------------
static func _num(n: int) -> String:
	# 15000 -> "15,000"
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


func _mat(c: Color, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.5
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	parent.add_child(mi)
	return mi


func _label3d(parent: Node3D, text: String, size: int, at: Vector3) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.01
	l.outline_size = 10
	l.modulate = Color(1, 0.95, 0.75)
	l.outline_modulate = Color(0.15, 0.08, 0.2)
	l.position = at
	parent.add_child(l)
	return l

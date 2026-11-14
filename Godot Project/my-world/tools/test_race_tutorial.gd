extends SceneTree

# Checks the races' tutorial (scripts/race_tutorial.gd) and a clear start on every circuit (Hayden's 13 Nov 2026
# playtest: "THE LAKE LOOP RACE STARTS OFF WITH A BUMPER RIGHT IN FRONT OF YOU. there needs to be a tutorial for
# starting races").
#
#   - Every circuit's start is clear: no obstacle or goo from 34 m before the line (the grid) to 12 m after it.
#   - Near Zippy's race gate the card says to talk to him; talking ticks it off and it goes.
#   - The first race teaches as you go: GO, the gold ring, a Star Box, using it, the obstacles, the map; each step
#     ticks off when it's done, and finishing the race ends it for good.
#   - A save that's raced before, or tips off, never sees the lesson.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_race_tutorial.gd
#
# Your own save and settings are put aside (under names of their own) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.race_tut_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.race_tut_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0
var game: Node
var settings: Node
var dialogue: Node
var races: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(500.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	settings = root.get_node("Settings")
	dialogue = root.get_node("Dialogue")
	races = root.get_node("Races")
	settings.use_layout("classic")
	settings.last_device = "keyboard"
	settings.tips = true
	settings.race_intros = false
	settings.skate_assist = 0                       # (Relaxed: the friends wait longest between attacks)
	game._resume = {}
	game.pending_message = ""
	game.riding = false
	game.hold_saves = true
	races.reset()
	for f in dialogue.flags.keys():
		if str(f).begins_with("race_"):
			dialogue.flags.erase(f)
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	root.get_node("Clock").set("pulls_home", false)

	# --- Every circuit's start is clear (worked out from the track's own numbers, as race_track.gd lays it) ---
	var rt: GDScript = load("res://scripts/race_track.gd")
	for id in races.TRACKS:
		var tr: Dictionary = races.TRACKS[id]
		if not tr.has("circuit"):
			continue
		var cpi: Array[int] = []
		var flat: Array = rt.spline(tr.points, cpi)
		var dist: Array[float] = []
		var tot := 0.0
		for i in flat.size():
			if i > 0:
				tot += Vector2(flat[i].x, flat[i].z).distance_to(Vector2(flat[i - 1].x, flat[i - 1].z))
			dist.append(tot)
		var L: float = tot + Vector2(flat[0].x, flat[0].z).distance_to(Vector2(flat[-1].x, flat[-1].z))
		var bad: Array[String] = []
		for kind in ["obstacles", "goo"]:
			for o in tr.get(kind, []):
				var seg := float(o[0])
				var i := clampi(int(floor(seg)), 0, cpi.size() - 1)
				var a: float = dist[cpi[i]]
				var b: float = dist[cpi[i + 1]] if i + 1 < cpi.size() else L
				var d: float = a + (b - a) * (seg - i)
				var rel: float = d if d < L / 2.0 else d - L
				if rel > -34.0 and rel < 12.0:
					bad.append("%s %s at %.0f m" % [kind, str(o), rel])
		check(bad.is_empty(), "%s: the grid and the start are clear (%s)" % [tr.name, ", ".join(bad)])

	# --- The gate card ---
	change_scene_to_file(TOWN)
	await _frames(6)
	var p := current_scene.find_child("Player", true, false) as CharacterBody3D
	var gate: Node3D = races.hub_node("void")
	await _until(func() -> bool: return gate != null and gate.ready_to_race, 60)
	var tut: CanvasLayer = races.tutorial
	p.global_position = Vector3(60, 2, 60)
	await _frames(4)
	check(tut.showing() == "", "far from the race gate, no card")
	var zippy: Node3D = gate.get_node("Zippy")
	p.global_position = zippy.global_position + Vector3(4, 1, 0)
	await _frames(4)
	check(tut.showing() == "gate", "near the race gate, a card says who to talk to")
	check(tut._text.text.contains("Zippy") and tut._text.text.contains("race"), "...Zippy, to pick a race (%s)" % tut._text.text)
	game.items.erase("skateboard")
	await _frames(3)
	check(tut.showing() == "", "with nothing to ride, no card yet")
	game.items.append("skateboard")
	await _frames(3)
	var spot: Node3D = null
	for c in zippy.find_children("*", "Node3D", true, false):
		if c.has_method("interact") or str(c.get_script().resource_path if c.get_script() else "").ends_with("race_spot.gd"):
			spot = c
			break
	check(spot != null, "Zippy has a talk spot")
	if spot:
		races.talk(spot)
	await _frames(2)
	check(dialogue.flags.has("race_gate_seen"), "talking to Zippy ticks the gate card off")
	if dialogue.has_method("end"):
		dialogue.end()
	await _frames(4)
	check(tut.showing() == "", "...and it's gone for good")

	# --- The first race teaches as you go ---
	check(races.enter_circuit("lake_loop"), "off to the Lake Loop")
	var lake: String = races.TRACKS.lake_loop.scene
	await _until(func() -> bool: return current_scene != null and current_scene.scene_file_path == lake and races.racing(), 300)
	p = current_scene.find_child("Player", true, false) as CharacterBody3D
	var t: Node3D = races.track_node("lake_loop")
	await _frames(2)
	check(races.state == races.State.COUNTDOWN and tut.showing() == "go", "in the countdown: when it says GO, ride forward")
	await _until(func() -> bool: return races.state == races.State.RACING, 300)
	Input.action_press("move_forward")
	await _until(func() -> bool: return tut.step_id() == "ring", 240)
	check(dialogue.flags.has("race_tut_go") and tut.step_id() == "ring", "riding off ticks it, then: ride through the gold ring")
	# Through the first ring
	var cp1: Vector3 = t.point_at(t.cp_dist[1])
	_put(p, cp1 - t.dir_at(t.cp_dist[1]) * 3.0 + Vector3.UP, t.dir_at(t.cp_dist[1]) * 9.0)
	await _until(func() -> bool: return tut.step_id() == "box", 200)
	check(races.last_cp >= 1 and tut.step_id() == "box", "through it: ride into a Star Box")
	Input.action_release("move_forward")
	races.power = "zoom"
	races.hud.show_power("Zoom Star")
	await _until(func() -> bool: return tut.step_id() == "use", 120)
	check(tut.step_id() == "use" and tut._text.text.contains("Zoom Star"), "a power-up in hand: press Aim to use it (%s)" % tut._text.text)
	check(tut._text.text.contains(settings.prompt("aim")), "...saying which button")
	races.use_power()
	await _until(func() -> bool: return tut.step_id() == "watch", 120)
	check(tut.step_id() == "watch" and tut._text.text.contains("Bumpers"), "used: then what the obstacles do")
	await _until(func() -> bool: return tut.step_id() == "map", 600)
	check(tut.step_id() == "map", "...and after a few seconds, the map and the laps")
	# Off the track and back mid-lesson: the card hides while a talk's up
	dialogue.flags.erase("x")
	await _until(func() -> bool: return not tut.running(), 600)
	check(not tut.running() and not dialogue.flags.has("race_tut_done"), "all read: the card goes (done for good at the finish)")
	# The finish
	races.lap = int(races.TRACKS.lake_loop.laps)
	races.last_cp = t.cp_dist.size() - 1
	races.next_cp = 0
	races._along = -1.0
	_put(p, t.point_at(t.length - 3.0) + Vector3.UP, t.dir_at(0.0) * 9.0)
	await _until(func() -> bool: return races.state == races.State.RESULTS, 200)
	check(races.state == races.State.RESULTS and dialogue.flags.has("race_tut_done"), "finishing the first race ends the lesson")
	races.restart()
	await _until(func() -> bool: return races.state == races.State.COUNTDOWN, 200)
	await _frames(3)
	check(tut.showing() == "", "the next race doesn't teach it again")

	# --- Old saves and tips off ---
	races._end(false)
	for f in dialogue.flags.keys():
		if str(f).begins_with("race_"):
			dialogue.flags.erase(f)
	races.raced = 3
	check(not tut.wanted(), "a save that's raced before isn't taught")
	races.raced = 0
	settings.tips = false
	check(not tut.wanted(), "...nor with tips off")
	settings.tips = true
	check(tut.wanted(), "(a new racer with tips on is)")
	_finish()


func _put(p: CharacterBody3D, at: Vector3, v: Vector3) -> void:
	p.global_position = at
	p.velocity = v


func _until(cond: Callable, frames: int) -> void:
	for i in frames:
		if cond.call():
			return
		await physics_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _finish() -> void:
	Input.action_release("move_forward")
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	print("RESULT %s (%d failed)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures > 0 else 0)

extends SceneTree

# Checks the speed coins and the flow (Hayden, 14 Nov 2026: "the speed coins should be in the races only, not the
# overworld. Once the player picks up a full "set" of coins, they enter a "flow" state where their speed is slightly
# increased and the screen becomes a little bit blurred on the edges and maybe psychedelic-melty a little bit"):
#
#   - No speed coins out in the Void or Stars Hollow (scripts/boosters.gd).
#   - Every circuit has sets of five coins on the road, spread round the lap, clear of obstacles, goo and the start (and
#     off the boost pads and Star Boxes themselves), shown only in a race.
#   - Each coin pushes you a little and goes (and comes back later); all five of a set puts you in the flow: quicker
#     (Skate.flow_speed) and the blurry, melty view on; missing one of a set doesn't. The flow wears off by itself,
#     ends with the race, and Reduce motion stops the melting.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_race_flow.gd
#
# Your own save and settings are put aside (under names of their own) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.race_flow_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.race_flow_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0
var game: Node
var settings: Node
var races: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(900.0, true, false, true).timeout.connect(func() -> void:
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
	races = root.get_node("Races")
	settings.use_layout("classic")
	settings.tips = false
	settings.race_intros = false
	settings.reduce_motion = false
	game._resume = {}
	game.pending_message = ""
	game.hold_saves = true
	races.reset()
	races.raced = 3
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	root.get_node("Clock").set("pulls_home", false)
	for k in races.TRACKS:
		if races.TRACKS[k].has("circuit"):
			races.finished_once[k] = true

	# --- None out in the world ---
	var out := 0
	for b in root.get_node("Boosters").BOOSTERS:
		out += 1 if str(b.kind) == "coins" else 0
	check(out == 0, "no speed coins out in the Void or Stars Hollow")

	# --- Every circuit's coins ---
	for id in races.TRACKS:
		var tr: Dictionary = races.TRACKS[id]
		if not tr.has("circuit"):
			continue
		change_scene_to_file(str(tr.scene))
		await _frames(4)
		await _until(func() -> bool:
			var tt: Node3D = races.track_node(id)
			return tt != null and tt.ready_to_race, 300)
		var t: Node3D = races.track_node(id)
		check(t.coin_sets.size() >= 2, "%s: %d sets of speed coins a lap" % [tr.name, t.coin_sets.size()])
		var busy: Array = []   # [where, how far a coin must keep off it]
		for key in ["goo", "obstacles"]:
			for b in tr.get(key, []):
				busy.append([t.at(float(b[0])), 8.0])
		for b in tr.get("boxes", []):
			busy.append([t.at(float(b[0])), 2.5])
		for b in tr.get("boosts", []):
			busy.append([t.at(float(b[0])), 1.5])
		var bad: Array[String] = []
		var starts: Array[float] = []
		for cs in t.coin_sets:
			check(cs.size() == 5, "%s: five coins in a set" % tr.name)
			starts.append(float(cs[0].get_meta("d")))
			for c in cs:
				var d: float = c.get_meta("d")
				if t.off_line(c.global_position, d) > t.width / 2.0 - 1.5:
					bad.append("%.0f m: off the road" % d)
				if d < 40.0 or d > t.length - 30.0:
					bad.append("%.0f m: by the start" % d)
				for b in busy:
					if absf(float(b[0]) - d) < float(b[1]):
						bad.append("%.0f m: by something at %.0f m" % [d, float(b[0])])
		check(bad.is_empty(), "%s: every coin is on the road, clear of everything else %s" % [tr.name, bad])
		starts.sort()
		var gap := INF
		for k in starts.size():
			gap = minf(gap, fposmod(starts[(k + 1) % starts.size()] - starts[k], t.length))
		check(gap > 45.0, "%s: the sets are spread round the lap (closest %.0f m apart)" % [tr.name, gap])

	# --- In a race: from Zippy's gate, as a player would ---
	races._end(false)
	change_scene_to_file(TOWN)
	await _frames(6)
	await _until(func() -> bool: return races.hub_node("void") != null and races.hub_node("void").ready_to_race, 120)
	check(races.enter_circuit("lake_loop"), "off to the Lake Loop")
	var lake: String = races.TRACKS.lake_loop.scene
	await _until(func() -> bool: return current_scene != null and current_scene.scene_file_path == lake and races.racing(), 300)
	await _until(func() -> bool: return races.state == races.State.RACING, 400)
	var p := current_scene.find_child("Player", true, false) as CharacterBody3D
	var t: Node3D = races.track_node("lake_loop")
	var skate: Node = p.get("skate")
	var flow: CanvasLayer = races.flow
	check(t.coin_sets[0][0].visible, "the coins are out in a race")
	var view := flow.get_node("Flow View") as ColorRect

	# Miss one of a set: no flow
	var miss: Array = t.coin_sets[1]
	for k in [0, 1, 2, 4]:
		await _on(p, miss[k])
	check(not flow.active(), "four of a set (one missed): no flow")
	check(not (miss[0].get_node("Spin") as Node3D).visible, "a coin goes when you take it")

	# The whole set
	var set0: Array = t.coin_sets[0]
	var before: int = flow.times
	for k in 4:
		await _on(p, set0[k])
	check(int(races._coin_got.get(0, 0)) == 4 and not flow.active(), "four coins of a set: nearly ('Coins 4/5')")
	await _on(p, set0[4])
	check(flow.active() and flow.times == before + 1, "all five: you're in the flow")
	for i in 90:
		await physics_frame
	check(flow.strength > 0.95, "...it fades in (%.2f)" % flow.strength)
	check(absf(float(skate.flow_speed) - flow.SPEED) < 0.1, "...you're quicker (+%.1f m/s)" % skate.flow_speed)
	check(view.visible and float((view.material as ShaderMaterial).get_shader_parameter("strength")) > 0.95, "...and the screen's edges go blurry and melty")
	check(float((view.material as ShaderMaterial).get_shader_parameter("melt")) > 0.5, "...melting")
	settings.reduce_motion = true
	await _frames(2)
	check(float((view.material as ShaderMaterial).get_shader_parameter("melt")) == 0.0, "...but not with Reduce motion")
	settings.reduce_motion = false

	# It wears off by itself
	flow.left = 0.05
	for i in 200:
		await physics_frame
	check(not flow.active() and flow.strength < 0.01 and not view.visible, "the flow wears off")
	check(float(skate.flow_speed) < 0.05, "...and you're back to your own speed")

	# Coins come back, and the set counts again
	for c in set0:
		c.set_meta("gone", 0.01)
	for i in 5:
		await physics_frame
	check((set0[0].get_node("Spin") as Node3D).visible, "the coins come back")
	for c in set0:
		await _on(p, c)
	check(flow.active(), "another whole set: in the flow again")

	# The race ends: straight out of it
	races._end(false)
	await process_frame
	check(not flow.active() and not view.visible and float(skate.flow_speed) == 0.0, "the race over, the flow's over")
	check(not t.coin_sets[0][0].visible, "...and the coins are put away")

	print("RESULT %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	_finish()


func _on(p: Node3D, coin: Node3D) -> void:
	# (Between the rings either side of it, as if you'd ridden there: jumping further round gets you put back on the
	# road where you'd got to.)
	var cps: Array = races.track.cp_dist
	var d: float = coin.get_meta("d")
	var k := 0
	for i in cps.size():
		if float(cps[i]) <= d:
			k = i
	races.last_cp = k
	races.next_cp = (k + 1) % cps.size()
	p.global_position = coin.global_position + Vector3.UP * 0.9
	p.velocity = Vector3.ZERO
	for i in 3:
		await physics_frame


func _until(cond: Callable, frames: int) -> void:
	for i in frames:
		if cond.call():
			return
		await physics_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	else:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	quit(1 if failures > 0 else 0)

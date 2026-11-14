extends SceneTree

# Checks the races (scripts/races.gd, race_track.gd, race_rival.gd, race_hud.gd, race_attacks.gd, race_circuit.gd).
# Since Hayden's day 1 playtest (11 Nov 2026) the ground races are circuits of their own: out in the Void there's only
# Zippy's race gate (the arch, Zippy, the board and the Tune-Up, no track), and saying which race takes you to its
# circuit. This checks: the gate, and that no track is left in town; the trip there (the clock waits) and the race
# starting by itself, eight racers with you in the middle of the pack; every circuit's road (solid all the way round,
# walls both sides, never too steep, never crossing itself, scenery and the starter off it, obstacles on it); the
# countdown; each obstacle (bumpers bounce you, sweepers and zappers knock you over, ramps throw you up); the power-ups
# (Zoom Star, Bubble Shield, Super Spring, Goo Bomb, Bubble Seeker, Zap Ring) on you and the friends; the friends
# picking power-ups up and using them on you (and the shield stopping it); being popped back on the road; laps, the
# finish and its prize, the results with "race again" and "back"; racing again; saving on a circuit (you're saved back
# at the gate); going back; the next race opening; Zippy's Tune-Up; the Sky Rings (still in the Void's sky); saving.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_races.gd
#
# Your own save and settings are put aside (under names of their own) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.races_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.races_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0
var game: Node
var settings: Node
var dialogue: Node
var races: Node
var clock: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(700.0, true, false, true).timeout.connect(func() -> void:
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
	clock = root.get_node("Clock")
	settings.use_layout("classic")
	settings.last_device = "keyboard"
	settings.tips = false
	settings.race_intros = false                    # the intros have their own test (test_race_intros)
	settings.skate_assist = 1
	game._resume = {}
	game.pending_message = ""
	game.riding = false
	game.hold_saves = true
	races.reset()
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	clock.set("pulls_home", false)

	change_scene_to_file(TOWN)
	await _frames(6)
	var town := current_scene
	var p := town.find_child("Player", true, false) as CharacterBody3D
	var gate: Node3D = races.hub_node("void")
	for i in 60:
		if gate and gate.ready_to_race:
			break
		await physics_frame
	# --- The race gate: no track left in town ---
	check(gate != null and gate.ready_to_race, "Zippy's race gate is put up in town at play time")
	check(races.track_node("lake_loop") == null and races.track_node("meadow_wiggle") == null and races.track_node("observatory_hill") == null,
		"...and no race track is laid out in town any more")
	var left: Array = town.get_children().filter(func(n: Node) -> bool: return str(n.name).begins_with("Race ") and not str(n.name).begins_with("Race Gate"))
	check(left.size() == 1 and str(left[0].name) == "Race sky_rings", "(only the Sky Rings, up in the sky: %s)" % ", ".join(left.map(func(n: Node) -> String: return str(n.name))))
	check(gate.get_node_or_null("Zippy") != null and gate.get_node_or_null("Race Board") != null and gate.get_node_or_null("Start Arch") != null
		and gate.get_node_or_null("Tune-Up") != null, "the gate has its arch, Zippy, the board and the Tune-Up")
	check(gate.rings.is_empty() and gate.pads.is_empty() and gate.boxes.is_empty(), "...and no rings, pads or boxes")
	check(gate.get_node("Zippy").global_position.distance_to(Vector3(-8, gate.get_node("Zippy").global_position.y, 32.5)) < 2.0,
		"Zippy stands where he always did, by the lake")
	check(gate.board_text.text.contains("LAKE LOOP") and gate.board_text.text.contains("Opens after"),
		"the board lists the races, and which open later")
	var lines: Array = races.hub_lines("void")
	var picks: Array = lines.filter(func(l) -> bool: return l is Dictionary and l.has("choice"))[0].choice
	check(picks.any(func(c: Dictionary) -> bool: return c.get("set", "") == "race_go_lake_loop")
		and not picks.any(func(c: Dictionary) -> bool: return c.get("set", "") == "race_go_meadow_wiggle"),
		"Zippy offers the Lake Loop, not a race that isn't open yet")
	check(str(lines).contains("throw"), "...and says the others throw things too")
	game.items.erase("skateboard")
	check(str(races.hub_lines("void")).contains("Skate Park") and not races.enter_circuit("lake_loop"),
		"with nothing to ride, Zippy says where the skateboard is, and nobody goes")
	game.items.append("skateboard")
	var map_flags: Array = races.map_tracks().filter(func(tr: Dictionary) -> bool: return tr.name == "Races")
	check(map_flags.size() == 1, "the map shows the race gate")

	# --- Off to the Lake Loop ---
	p.global_position = gate.get_node("Zippy").global_position + Vector3(2, 1, 0)
	await _physics(3)
	var from: Vector3 = p.global_position
	dialogue.flags["race_go_lake_loop"] = true
	dialogue.finished.emit("race_starter")
	var lake_scene: String = races.TRACKS.lake_loop.scene
	await _until(func() -> bool: return current_scene != null and current_scene.scene_file_path == lake_scene, 240)
	check(current_scene.scene_file_path == lake_scene, "saying which takes you to the Lake Loop's own circuit")
	var circ := current_scene
	p = circ.find_child("Player", true, false) as CharacterBody3D
	var s: Node = p.get_node("Skate")
	await _until(func() -> bool: return races.racing(), 240)
	var t: Node3D = races.track_node("lake_loop")
	check(races.circuit == "lake_loop" and races.racing() and races.state == races.State.COUNTDOWN, "...and the race starts by itself")
	check(not clock.running, "the clocks wait while you race")
	check(races.rivals.size() == 7, "seven friends race you (%s)" % ", ".join(races.rivals.map(func(r) -> String: return r.id)))
	var ahead: int = races.rivals.filter(func(r) -> bool: return r.d > -13.0).size()
	check(ahead == 4, "you start fifth, in the middle of the pack (%d in front)" % ahead)
	check(p.input_locked, "nobody moves during the countdown")
	check(races.hud.map.visible, "a little map of the track is up")
	await _check_circuit("lake_loop", t, p)
	await _physics(200)
	check(races.state == races.State.RACING and not p.input_locked, "GO: the race is on")
	var behind: float = Vector2(p.global_position.x - t.point_at(0.0).x, p.global_position.z - t.point_at(0.0).z).length()
	check(behind > 8.0, "...and waiting on the grid, behind the line, nobody pops you forward (%.1f m back)" % behind)
	await _physics(120)
	var moved: float = races.rivals[0].d + 4.0
	check(moved > 8.0 and moved < 30.0, "the friends set off at a fair pace (%.1f m in 2 s)" % moved)

	# --- Obstacles ---
	for r in races.rivals:
		r.d = -60.0                                         # (out of the way)
		r.speed = 0.0
		r.skill = 0.0
		r.item = ""
	races.attacks._aim_wait = 999.0
	var bumper: Node3D = _first(t, "bumper")
	_jump(t, p, bumper.global_position - t.dir_at(float(bumper.get_meta("d"))) * 1.6 + Vector3.UP * 0.9, t.dir_at(float(bumper.get_meta("d"))) * 7.0)
	await _physics(6)
	var away: Vector3 = p.global_position - bumper.global_position
	check(Vector2(away.x, away.z).length() > 1.6 and p.velocity.dot(t.dir_at(float(bumper.get_meta("d")))) < 4.0,
		"a bumper bounces you off it (%.1f m away, %.1f m/s on)" % [Vector2(away.x, away.z).length(), p.velocity.dot(t.dir_at(float(bumper.get_meta("d"))))])
	await _physics(60)
	var sweeper: Node3D = _first(t, "sweeper")
	races._knock_safe = 0.0
	var arm := sweeper.get_node("Arm") as Node3D
	arm.rotation.y = 0.0
	sweeper.set_meta("speed", 0.0)
	_jump(t, p, sweeper.global_transform * Vector3(3.0, 0.0, 0.0) + Vector3.UP * 0.9, Vector3.ZERO)
	await _physics(3)
	check(s.is_bailing(), "a sweeper's arm knocks you over")
	await _physics(150)
	sweeper.set_meta("speed", 1.1)
	var zapper: Node3D = _first(t, "zapper")
	races._knock_safe = 0.0
	t._t = -float(zapper.get_meta("phase"))                 # (just switched on)
	_jump(t, p, zapper.global_position + Vector3.UP * 0.9, Vector3.ZERO)
	await _physics(2)
	check(t.zap_on(zapper) and s.is_bailing(), "a zapper that's on knocks you over")
	await _physics(150)
	races._knock_safe = 0.0
	t._t = -float(zapper.get_meta("phase")) + 1.6           # (off)
	_jump(t, p, zapper.global_position + Vector3.UP * 0.9, Vector3.ZERO)
	await _physics(2)
	check(not t.zap_on(zapper) and not s.is_bailing(), "...but not when it's off")
	var ramp: Node3D = _first(t, "ramp")
	var rd: float = ramp.get_meta("d")
	_jump(t, p, t.point_at(rd - 2.0) + Vector3.UP * 0.9, t.dir_at(rd) * 8.0)
	await _physics(30)
	check(p.global_position.y > t.point_at(rd).y + 2.0, "a ramp throws you up in the air (%.1f m up)" % (p.global_position.y - t.point_at(rd).y))
	await _physics(120)

	# --- Over the wall: back on the road ---
	var wd: float = t.cp_dist[3]
	_jump(t, p, t.point_at(wd) + t.side_at(wd) * 14.0 + Vector3.UP * 0.5, Vector3.ZERO)
	await _physics(3)
	check(t.off_line(p.global_position, wd) < 2.0, "off over a wall, you're popped back on the road")
	game.riding = false
	game.equipment_changed.emit()
	await _physics(3)
	check(races.racing() and game.riding, "stepping off on a circuit just puts you back on your ride")
	await _physics(30)

	# --- Power-ups ---
	_jump(t, p, t.point_at(t.cp_dist[4] + 2.0) + Vector3.UP * 0.9, t.dir_at(t.cp_dist[4]) * 6.0)
	await _physics(2)
	var box: Node3D = t.boxes[5]
	_jump(t, p, box.global_position + Vector3.DOWN * 0.3 + Vector3.UP * 0.85, Vector3.ZERO)
	await _physics(3)
	check(races.power != "" and races.hud.power_box.visible, "a Star Box gives a power-up (%s)" % races.power)
	check(t.boxes.size() == races.TRACKS.lake_loop.boxes.size() * 4, "rows of four Star Boxes across the road")
	var here: float = races.progress
	var dash: Node = races.rivals[0]
	dash.d = here + 10.0
	dash.lane = 0.0
	dash.lane_goal = 0.0
	dash._running = 1.0
	_jump(t, p, t.point_at(here) + Vector3.UP * 0.9, Vector3.ZERO)
	await _physics(2)
	races.power = "seeker"
	check(races.use_power() and races.attacks.seekers.size() == 1, "a Bubble Seeker goes after the racer ahead")
	await _until(func() -> bool: return races.attacks.seekers.is_empty(), 120)
	check(dash.stunned(), "...and knocks %s round" % dash.display_name())
	await _physics(120)
	dash.d = races.progress - 4.0
	races.power = "goo"
	races.use_power()
	check(races.attacks.drops.size() == 1, "a Goo Bomb drops a puddle behind you")
	dash.lane = (races.attacks.drops[0].node.global_position - t.point_at(dash.d)).dot(t.side_at(dash.d))
	dash.lane_goal = dash.lane
	dash.d = t.nearest(races.attacks.drops[0].node.global_position, races.progress, 20.0) - 0.2
	dash._shield = 0.0
	await _physics(4)
	check(dash._slow > 0.0, "...that slows down whoever rides through it")
	var rex: Node = races.rivals[1]
	rex.d = races.progress + 1.0
	rex.lane = 0.0
	rex._stun = 0.0
	rex._shield = 0.0
	_jump(t, p, t.point_at(races.progress) + Vector3.UP * 0.9, Vector3.ZERO)
	await _physics(2)
	races.power = "zap"
	races.use_power()
	check(rex.stunned(), "a Zap Ring knocks round everyone close by")
	rex._stun = 0.0
	rex.shield_up(5.0)
	races.attacks.hit(rex, "test")
	check(not rex.stunned() and not rex.shielded(), "a friend's Bubble Shield stops a hit (and pops)")
	races.power = "zoom"
	check(races.use_power() and s.boosting(), "the Zoom Star boosts")
	races.power = "shield"
	check(races.use_power() and s.shielded, "the Bubble Shield goes up")
	await _physics(150)

	# --- The friends attack you ---
	races._knock_safe = 0.0
	var pip: Node = races.rivals[4]
	pip.d = races.progress - 8.0
	pip._running = 1.0
	pip._stun = 0.0
	await _physics(2)                                       # (so Pip is really there, 8 m behind, before throwing)
	pip.item = "seeker"
	pip.item_wait = 0.0
	pip.item_held = 0.0
	races.attacks._aim_wait = 0.0
	await _until(func() -> bool: return not races.attacks.seekers.is_empty(), 30)
	check(races.attacks.seekers.size() == 1 and races.attacks.seekers[0].target == p and pip.item == "",
		"a friend behind you sends a Bubble Seeker after you")
	check(races.attacks._aim_wait > 5.0, "...and then nobody aims at you for a while")
	races.power = "shield"
	races.use_power()
	s.set("_boost_time", 0.0)                               # (still zooming from the Zoom Star: let the bubble catch up)
	p.velocity = Vector3.ZERO
	await _until(func() -> bool: return races.attacks.seekers.is_empty(), 300)
	check(not s.is_bailing() and not races.shielded(), "your Bubble Shield takes it (and pops) (bailing %s, shield %s, seekers %d)" % [s.is_bailing(), races.shielded(), races.attacks.seekers.size()])
	races._knock_safe = 0.0
	races.attacks._aim_wait = 0.0
	pip.d = races.progress - 8.0
	await _physics(2)
	pip.item = "seeker"
	pip.item_wait = 0.0
	await _until(func() -> bool: return s.is_bailing(), 150)
	check(s.is_bailing(), "without it, the Bubble Seeker knocks you over")
	await _physics(150)
	for r in races.rivals:
		r.item = ""
	races.attacks._aim_wait = 999.0
	# Picking up from the boxes
	var mr: Node = races.rivals[2]
	mr.item = ""
	mr.d = float(t.boxes[0].get_meta("d")) - 0.5
	mr.speed = 8.0
	mr._running = 1.0
	await _physics(10)
	check(mr.item != "", "the friends pick power-ups up from the Star Boxes too (%s: %s)" % [mr.display_name(), mr.item])
	mr.item = ""
	# Steering round a bumper
	var b2: Node3D = _first(t, "bumper")
	var cleared = races.rivals[3]
	cleared.d = float(b2.get_meta("d")) - 12.0
	cleared.lane = float(b2.get_meta("side"))
	cleared.lane_goal = cleared.lane
	cleared.skill = 1.0
	cleared._stun = 0.0
	cleared._slow = 0.0
	await _physics(70)
	check(absf(cleared.lane - float(b2.get_meta("side"))) > 1.5, "a friend steers round a bumper ahead (lane %.1f, bumper %.1f)" % [cleared.lane, float(b2.get_meta("side"))])

	# --- Round the rings: laps and the finish ---
	races._end(false)
	await _physics(2)
	game.add_sparkles(0)
	var sparkles_before: int = game.sparkles
	check(races.restart() and races.state == races.State.COUNTDOWN, "racing again starts the countdown")
	await _physics(200)
	for r in races.rivals:
		r.d = -60.0
		r.speed = 0.0
		r.skill = 0.0
	races.attacks._aim_wait = 999.0
	_put(p, t.point_at(t.cp_dist[4] + 0.5) + Vector3.UP * 0.9, Vector3.ZERO)
	await _physics(3)
	check(races.next_cp == 1, "riding through a later ring doesn't count (next is still 1)")
	var laps: int = races.TRACKS.lake_loop.laps
	check(laps == 3, "three laps")
	for lap in laps:
		for i in range(1, t.cp_dist.size() + 1):
			var cp: int = i % t.cp_dist.size()
			_put(p, t.point_at(t.cp_dist[cp] - 2.5) + Vector3.UP * 0.9, t.dir_at(t.cp_dist[cp]) * 6.0)
			await _physics(2)
			_put(p, t.point_at(t.cp_dist[cp] + 1.0) + Vector3.UP * 0.9, t.dir_at(t.cp_dist[cp]) * 6.0)
			await _physics(2)
	check(races.state == races.State.RESULTS and races.place == 1, "over the line after %d laps: you won" % laps)
	var prize: int = races.TRACKS.lake_loop.prizes[0]
	check(game.sparkles - sparkles_before == prize, "1st pays ✦ %d (got %d)" % [prize, game.sparkles - sparkles_before])
	check(races.hud.results.visible and races.hud.choosing() and races.hud.choice_box.get_child_count() == 2,
		"the results come with two buttons: race again, or go back")
	check(p.input_locked, "...and you wait while they're up")
	await _physics(int(races.RESULTS_TIME * 60) + 10)
	check(races.hud.choosing(), "...for as long as you like")
	# The buttons keep the mouse cursor (Hayden's 12 Nov playtest: after a race the cursor was gone for good)
	var windowed := DisplayServer.get_name() != "headless"
	check(not windowed or Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "the results show the mouse cursor")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	p.get_node("SpringArm3D")._unhandled_input(click)
	await _frames(2)
	check(not windowed or Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "...clicking the game behind them doesn't hide it")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _frames(2)
	check(not windowed or Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "...nor does anything else grabbing the mouse")
	var pause_menu: Node = root.get_node("PauseMenu")
	pause_menu.open()
	pause_menu.close()
	check(not windowed or Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "...nor pausing and carrying on")
	check(races.best.has("lake_loop") and int(races.wins.get("lake_loop", 0)) == 1, "best time and the win are kept")
	var saved: Dictionary = races.save_place()
	check(saved.get("scene", "") == TOWN and Vector3(saved.position[0], saved.position[1], saved.position[2]).distance_to(from) < 1.0,
		"saving on a circuit saves you back at the race gate")
	(races.hud.choice_box.get_child(0) as Button).pressed.emit()
	await _physics(3)
	check(races.racing() and races.state == races.State.COUNTDOWN and not races.hud.choosing(), "\"Race again\" goes straight back to the countdown")
	check(not windowed or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "...and the game has the mouse again")
	races._end(false)
	races._offer_choice("test")
	(races.hud.choice_box.get_child(1) as Button).pressed.emit()
	await _until(func() -> bool: return current_scene != null and current_scene.scene_file_path == TOWN, 240)
	await _frames(4)
	check(current_scene.scene_file_path == TOWN and races.circuit == "", "\"Back to the Void\" takes you back")
	p = current_scene.find_child("Player", true, false) as CharacterBody3D
	await _physics(10)
	check(p.global_position.distance_to(from) < 3.0, "...to where you set off from, by the gate (%.1f m)" % p.global_position.distance_to(from))
	check(clock.running and not p.input_locked, "...and the clocks run again")
	check(races.unlocked("meadow_wiggle") and not races.unlocked("observatory_hill"), "finishing the Lake Loop opens the Meadow Wiggle")
	picks = races.hub_lines("void").filter(func(l) -> bool: return l is Dictionary and l.has("choice"))[0].choice
	check(picks.any(func(c: Dictionary) -> bool: return c.get("set", "") == "race_go_meadow_wiggle"), "...and Zippy offers it now")
	gate = races.hub_node("void")
	await _until(func() -> bool: return gate.ready_to_race, 60)
	check(gate.board_text.text.contains("Best: 0:") or gate.board_text.text.contains("Best: 1:") or gate.board_text.text.contains("Best: 2:"),
		"the board shows the best time")

	# --- Every circuit: a sound road ---
	for id in ["meadow_wiggle", "observatory_hill"]:
		races.finished_once[races.TRACKS[id].get("after", "")] = true
		check(races.enter_circuit(id), "off to the %s" % races.TRACKS[id].name)
		var path: String = races.TRACKS[id].scene
		await _until(func() -> bool: return current_scene != null and current_scene.scene_file_path == path, 240)
		await _until(func() -> bool: return races.racing(), 240)
		var tn: Node3D = races.track_node(id)
		check(races.racing() and races.rivals.size() == 7, "%s: racing seven friends" % races.TRACKS[id].name)
		await _check_circuit(id, tn, current_scene.find_child("Player", true, false))
		races.leave_circuit()
		await _until(func() -> bool: return current_scene != null and current_scene.scene_file_path == TOWN, 240)
		await _frames(4)
	check(current_scene.scene_file_path == TOWN, "leaving mid-race goes back too")
	town = current_scene
	p = town.find_child("Player", true, false) as CharacterBody3D
	s = p.get_node("Skate")
	gate = races.hub_node("void")
	await _until(func() -> bool: return gate.ready_to_race, 60)

	# --- Riding as Dash: someone else takes his place ---
	var lake: Dictionary = races.TRACKS.lake_loop
	check(not "bruno" in lake.rivals, "(the Lake Loop's line-up has no Bruno, so he can stand in)")

	# --- Zippy's Tune-Up: ride upgrades through the shared shop ---
	game.riding = true
	game.equipment_changed.emit()
	await _physics(3)
	var shop := root.get_node("Shop")
	check(gate.get_node("Tune-Up").find_child("Tune-Up Spot", true, false) != null, "Zippy's Tune-Up is at the gate")
	var tune: Array = shop.items.values().filter(func(i: Dictionary) -> bool: return i.stall == "Tune-Up" and i.kind != "ride")
	check(tune.size() == 13, "it sells 4 upgrades in 3 levels and the Starter Star (%d)" % tune.size())
	game.sparkles = 200
	var base_push: float = s.ride.push_speed
	check(shop.buy("tune_wheels_1") and races.level("wheels") == 1, "buying Speedy Wheels I")
	check(absf(float(s.ride.push_speed) - base_push * 1.05) < 0.01, "...makes the ride faster (%.2f -> %.2f)" % [base_push, s.ride.push_speed])
	shop.buy("tune_wheels_2")
	shop.buy("tune_turbo_1")
	check(absf(races.boost_time(2.0) - 2.5) < 0.01, "Turbo Tank makes boosts last longer")
	shop.buy("tune_starter_star")

	# --- The sky race: through the gold ring in the mothership ---
	var sky: Node3D = races.track_node("sky_rings")
	var ship: Node3D = town.get_tree().get_first_node_in_group("mothership")
	check(sky.rings[0].visible and not sky.rings[2].visible, "the Sky Rings' gold start ring waits in the sky (it's open)")
	game.riding = false
	game.equipment_changed.emit()
	ship.global_position = p.global_position + Vector3.UP * 20.0
	ship.board(p)
	for i in 240:
		if ship.is_piloted():
			break
		await physics_frame
	check(ship.is_piloted(), "flying the mothership")
	var s0: Vector3 = sky.point_at(0.0)
	var sf: Vector3 = sky.dir_at(0.0)
	ship.global_position = s0 - sf * 20.0
	await _physics(3)
	check(not races.racing(), "...nothing starts until it flies through the ring")
	ship.global_position = s0 + sf * 2.0
	await _physics(3)
	check(races.racing() and races.track_id == "sky_rings" and races.rivals.size() == 3, "through the gold ring: the sky race is on, against three saucers")
	await _physics(120)
	sparkles_before = game.sparkles
	for i in range(1, sky.cp_dist.size() + 1):
		var cp: int = i % sky.cp_dist.size()
		ship.global_position = sky.point_at(sky.cp_dist[cp] - 3.0)
		await _physics(2)
		ship.global_position = sky.point_at(sky.cp_dist[cp] + 1.0)
		await _physics(2)
	check(races.state == races.State.RESULTS, "one lap of the rings and it's finished")
	check(game.sparkles > sparkles_before, "...with sparkles for it (%d)" % (game.sparkles - sparkles_before))
	races._end(true)
	ship.beam_down()
	await _physics(200)

	# --- Saved ---
	var data: Dictionary = races.save_data()
	races.reset()
	races.load_data(data)
	check(races.best.has("lake_loop") and int(races.wins.lake_loop) == 1, "best times and wins load back")
	check(races.level("wheels") == 2 and races.level("starter") == 1, "...and the upgrades")
	races.reset()
	check(races.level("wheels") == 0, "a new game starts with no upgrades")

	_finish()


func _first(t: Node3D, kind: String) -> Node3D:
	for o in t.obstacles:
		if str(o.get_meta("kind")) == kind:
			return o
	return null


func _check_circuit(id: String, t: Node3D, p: CharacterBody3D) -> void:
	var tr: Dictionary = races.TRACKS[id]
	var circ: Node3D = current_scene
	var L: float = t.length
	var hw: float = tr.width / 2.0
	check(L > 380.0 and L < 900.0, "%s: a long lap (%.0f m), %d laps" % [tr.name, L, int(tr.laps)])
	check(t.cp_dist.size() == tr.points.size(), "%s: a ring for every checkpoint (%d)" % [tr.name, t.cp_dist.size()])
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var off_road := 0
	var no_wall := 0
	var steep := 0
	var worst := 0.0
	for i in t.line.size():
		var a: Vector3 = t.line[i]
		var b: Vector3 = t.line[(i + 1) % t.line.size()]
		for lane in [-hw + 0.6, 0.0, hw - 0.6]:
			var at: Vector3 = a + t.side_at(t.dist[i]) * lane
			var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 4.0, at + Vector3.DOWN * 4.0)
			q.exclude = [p.get_rid()]
			var hit: Dictionary = space.intersect_ray(q)
			if hit.is_empty() or str((hit.collider as Node).name) != "Road Body":
				off_road += 1
		var run := Vector2(b.x - a.x, b.z - a.z).length()
		worst = maxf(worst, absf(b.y - a.y) / maxf(run, 0.01))
		if absf(b.y - a.y) / maxf(run, 0.01) > 0.25:
			steep += 1
		# (Where a secret shortcut leaves or joins the road its wall is open on purpose: tools/test_race_tracks.gd)
		if i % 10 == 0 and not circ._open.has(circ.index_at(t.dist[i])):
			for side in [-1.0, 1.0]:
				var from: Vector3 = a + Vector3.UP * 0.5
				var q := PhysicsRayQueryParameters3D.create(from, from + t.side_at(t.dist[i]) * side * (hw + 3.0))
				q.exclude = [p.get_rid()]
				var hit: Dictionary = space.intersect_ray(q)
				if hit.is_empty() or absf(Vector2(hit.position.x - a.x, hit.position.z - a.z).length() - hw) > 0.6:
					no_wall += 1
	check(off_road == 0, "%s: the road is solid all the way round, every lane (%d gaps)" % [tr.name, off_road])
	check(no_wall == 0, "%s: walls both sides all the way round (%d missing)" % [tr.name, no_wall])
	# No bend so tight that the road's inside edge folds over itself (radius under the road's half width plus a wall)
	var tightest := INF
	for i in t.line.size():
		var a3: Vector3 = t.line[i - 3]
		var b3: Vector3 = t.line[i]
		var c3: Vector3 = t.line[(i + 3) % t.line.size()]
		var ab := Vector2(b3.x - a3.x, b3.z - a3.z)
		var ac := Vector2(c3.x - a3.x, c3.z - a3.z)
		var cr := absf(ab.cross(ac))
		if cr > 0.0001:
			tightest = minf(tightest, ab.length() * Vector2(c3.x - b3.x, c3.z - b3.z).length() * ac.length() / (2.0 * cr))
	check(tightest > hw + 4.0, "%s: no bend too tight for the road (tightest %.1f m round)" % [tr.name, tightest])
	check(steep == 0, "%s: never too steep to ride (steepest %.0f%%)" % [tr.name, worst * 100.0])
	# Never crossing itself: points far apart along the road are far apart on the ground
	var crossing := ""
	for i in range(0, t.line.size(), 3):
		for j in range(i + 3, t.line.size(), 3):
			var along := absf(t.dist[j] - t.dist[i])
			along = minf(along, L - along)
			if along > tr.width * 3.0 and Vector2(t.line[i].x - t.line[j].x, t.line[i].z - t.line[j].z).length() < tr.width + 2.0:
				crossing = "(%.0f, %.0f) and (%.0f, %.0f)" % [t.line[i].x, t.line[i].z, t.line[j].x, t.line[j].z]
	check(crossing == "", "%s: the road never runs into itself %s" % [tr.name, crossing])
	# The scenery stands off the road; the obstacles are on it
	var in_way: Array[String] = []
	for n in circ.get_children():
		if n is Node3D and str(n.name).split("@")[0].strip_edges() in ["Orb Tree", "Crystals", "Tree", "Mushroom", "Windmill", "Barn", "Stand"]:
			if circ.off_road(Vector2((n as Node3D).global_position.x, (n as Node3D).global_position.z)) < hw + 2.0:
				in_way.append("%s (%.0f, %.0f)" % [n.name, (n as Node3D).global_position.x, (n as Node3D).global_position.z])
	check(in_way.is_empty(), "%s: no scenery on the road (%s)" % [tr.name, ", ".join(in_way)])
	var bad: Array[String] = []
	for o in t.obstacles:
		var side: float = o.get_meta("side")
		var extent := 1.4 if str(o.get_meta("kind")) == "bumper" else (3.6 if str(o.get_meta("kind")) == "zapper" else 0.0)
		if absf(side) + extent > hw + 0.1:
			bad.append(str(o.name))
	check(t.obstacles.size() == tr.obstacles.size() and bad.is_empty(), "%s: %d obstacles, all on the road (%s)" % [tr.name, t.obstacles.size(), ", ".join(bad)])
	# The start is clear: nothing on the grid or just past the line (Hayden, 13 Nov 2026: "THE LAKE LOOP RACE STARTS OFF
	# WITH A BUMPER RIGHT IN FRONT OF YOU"). The grid reaches 22 m back, so nothing from 34 m before the line to 12 m on.
	var on_grid: Array[String] = []
	for o in t.obstacles + t.goo:
		var d: float = t.nearest((o as Node3D).global_position)
		var rel: float = d if d < L / 2.0 else d - L
		if rel > -34.0 and rel < 12.0:
			on_grid.append("%s %.0f m" % [o.name, rel])
	check(on_grid.is_empty(), "%s: nothing in the way on the grid or just past the line (%s)" % [tr.name, ", ".join(on_grid)])
	var kinds := {}
	for o in t.obstacles:
		kinds[str(o.get_meta("kind"))] = true
	check(["bumper", "sweeper", "zapper", "ramp"].all(func(k: String) -> bool: return kinds.has(k)),
		"%s: bumpers, sweepers, zappers and ramps (%s)" % [tr.name, ", ".join(kinds.keys())])
	var st := t.get_node_or_null(str(tr.starter.name)) as Node3D
	check(st != null and t.off_line(st.global_position, t.nearest(st.global_position)) > hw + 1.0, "%s: %s stands off the road" % [tr.name, tr.starter.name])
	# Nothing solid across the road (the arch's towers stand outside the walls)
	var blocked: Array[String] = []
	for i in range(0, t.line.size(), 2):
		var a: Vector3 = t.line[i]
		var b: Vector3 = t.line[(i + 2) % t.line.size()]
		for lane in [-hw + 1.0, 0.0, hw - 1.0]:
			var la: Vector3 = a + t.side_at(t.dist[i]) * lane
			var lb: Vector3 = b + t.side_at(t.dist[(i + 2) % t.line.size()]) * lane
			var q := PhysicsRayQueryParameters3D.create(la + Vector3.UP * 0.7, lb + Vector3.UP * (0.7 + maxf(lb.y - la.y, 0.0)))
			q.exclude = [p.get_rid()]
			var hit: Dictionary = space.intersect_ray(q)
			if not hit.is_empty() and blocked.size() < 6:
				blocked.append("%s at (%.0f, %.0f)" % [(hit.collider as Node).name, a.x, a.z])
	check(blocked.is_empty(), "%s: nothing solid across the road (%s)" % [tr.name, ", ".join(blocked)])
	await physics_frame


func _jump(t: Node3D, p: CharacterBody3D, at: Vector3, v: Vector3) -> void:
	# Puts her somewhere further round and tells the race she got there, so it doesn't pop her back to the ring she's
	# meant to be heading for (which is what happens to anyone who skips ahead).
	var d: float = t.nearest(at)
	var last := 0
	for i in t.cp_dist.size():
		if t.cp_dist[i] <= d:
			last = i
	races.last_cp = last
	races.next_cp = (last + 1) % t.cp_dist.size()
	races._along = -1.0
	_put(p, at, v)


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


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	else:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	print("RESULT %s (%d failed)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)

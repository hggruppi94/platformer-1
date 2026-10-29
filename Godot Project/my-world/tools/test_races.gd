extends SceneTree

# Checks the races (scripts/races.gd, race_track.gd, race_rival.gd, race_hud.gd): the Lake Loop is laid out on dry,
# open ground all the way round (nothing to crash into, no steps too high to roll up, well clear of the portal),
# Zippy and the board are there, talking to Zippy starts a race, the countdown holds everyone still, the rings go in
# order and count laps, the friends ride round at a fair pace and ease off or catch up, boost pads, goo, Star Boxes
# and all three power-ups do what they say, finishing pays the right prize and a best-time bonus, and the race ends
# cleanly (stepping off, results, back to normal). Best times and wins are saved.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_races.gd
#
# Your own save and settings are put aside (under names of their own) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.races_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.races_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const PORTAL := Vector2(36, 13)                   # the Portal to Earth (tools/build_town.gd), 3.8 m round its stone

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
	create_timer(300.0, true, false, true).timeout.connect(func() -> void:
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
	settings.tips = false
	settings.skate_assist = 1
	game._resume = {}
	game.pending_message = ""
	game.riding = false
	races.reset()
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)

	change_scene_to_file(TOWN)
	await _frames(6)
	var town := current_scene
	var p := town.find_child("Player", true, false) as CharacterBody3D
	var s: Node = p.get_node("Skate")
	var t: Node3D = races.track_node("lake_loop")
	check(t != null, "the Lake Loop is placed in town at play time")
	for i in 60:
		if t.ready_to_race:
			break
		await physics_frame
	check(t.ready_to_race, "...and its racing line is worked out")

	# --- Every track: laid out on dry, open ground ---
	for id in races.TRACKS:
		var tn: Node3D = races.track_node(id)
		for i in 60:
			if tn and tn.ready_to_race:
				break
			await physics_frame
		await _check_track(id, tn, p)
	check(t.pads.size() == 4 and t.boxes.size() == 9 and t.goo.size() == 3, "4 boost pads, 3 rows of Star Boxes, 3 goo puddles")
	check(t.pads[0].visible and not t.boxes[0].visible and not t.rings[1].visible,
		"boost pads are always out; boxes and rings only in a race")
	check(t.board_text.text.contains("LAKE LOOP") and t.board_text.text.contains("not yet"), "the board shows the race and no best time yet")

	# --- Boost pads work any time ---
	game.riding = true
	game.equipment_changed.emit()
	await _physics(3)
	var pad: Node3D = t.pads[0]
	p.global_position = pad.global_position + Vector3.UP * 0.85
	p.velocity = t.dir_at(float(pad.get_meta("d"))) * 4.0
	await _physics(3)
	check(s.boosting(), "riding over a boost pad boosts, race or no race")
	await _physics(20)
	var spd := Vector2(p.velocity.x, p.velocity.z).length()
	check(spd > 10.0, "...past pushing speed (%.1f m/s)" % spd)
	await _physics(80)

	# --- Talking to Zippy ---
	var lines: Array = races.lines()
	check(lines.any(func(l) -> bool: return l is Dictionary and l.has("choice")), "Zippy asks if you're ready")
	check(str(lines[1]).contains("Right"), "...and says how to use a power-up (%s)" % settings.prompt("aim"))
	game.items.erase("skateboard")
	check(str(races.lines()).contains("Skate Park"), "with nothing to ride, Zippy says where the skateboard is")
	check(not races.start("lake_loop"), "...and no race starts")
	game.items.append("skateboard")
	dialogue.flags["race_go_lake_loop"] = true
	dialogue.finished.emit("race_starter")
	await _frames(2)
	check(races.racing() and races.state == races.State.COUNTDOWN, "saying yes starts the countdown")
	check(races.rivals.size() == 3, "three friends line up (%s)" % ", ".join(races.rivals.map(func(r) -> String: return r.id)))
	check(p.input_locked, "nobody moves during the countdown")
	check(t.rings[1].visible and t.boxes[0].visible and t.goo[0].visible, "the rings, boxes and goo come out")
	var start_pos := p.global_position
	var d0: float = races.rivals[0].d
	await _physics(90)
	check(p.global_position.distance_to(start_pos) < 0.3 and races.rivals[0].d == d0, "...and they wait for GO")
	await _physics(110)
	check(races.state == races.State.RACING and not p.input_locked, "GO: the race is on")
	await _physics(120)
	var moved: float = races.rivals[0].d - d0
	check(moved > 6.0 and moved < 25.0, "the friends set off at a fair pace (%.1f m in 2 s)" % moved)
	check(races.place > 1, "standing still, you drop back (%s)" % races.hud.ordinal(races.place))
	# Ease off when far ahead
	var lead: Node3D = races.rivals[0]
	var base_speed: float = lead.speed
	lead.d = races.progress + 90.0
	await _physics(90)
	check(lead.speed < base_speed * 0.85, "a friend far ahead eases off (%.1f -> %.1f m/s)" % [base_speed, lead.speed])

	# --- Star Boxes, power-ups and goo ---
	var box: Node3D = t.boxes[1]
	p.global_position = box.global_position + Vector3.DOWN * 0.3 + Vector3.UP * 0.85
	await _physics(3)
	check(races.power != "", "a Star Box gives a power-up (%s)" % races.power)
	check(races.hud.power_box.visible, "...shown on the left with its button")
	check(float(box.get_meta("gone")) > 0.0, "...and the box pops for a while")
	_back_on_track(p, t, t.at(2.6))
	await _physics(10)
	races.power = "zoom"
	check(races.use_power() and s.boosting(), "the Zoom Star boosts")
	races.power = "shield"
	check(races.use_power() and s.shielded, "the Bubble Shield goes up")
	s.bail()
	check(not s.is_bailing(), "...and a fall is only a wobble while it's up")
	var goo: Node3D = t.goo[0]
	p.global_position = goo.global_position + Vector3.UP * 0.85
	await _physics(4)
	check(not s.slowed(), "...and goo can't slow you")
	races._clear_shield(p)
	await _physics(150)                               # the goo's wait, and the Zoom Star, wear off
	p.global_position = goo.global_position + Vector3.UP * 0.85
	p.velocity = Vector3.ZERO
	await _physics(4)
	check(s.slowed(), "goo slows you down without the shield")
	_back_on_track(p, t, t.at(5.8))
	await _physics(80)
	races.power = "spring"
	var vy_before := p.velocity.y
	check(races.use_power() and p.velocity.y > vy_before + 8.0, "the Super Spring is a huge hop (%.1f m/s up)" % p.velocity.y)
	await _physics(90)

	# --- Round the rings: they go in order and count the laps ---
	races._end(false)
	await _physics(2)
	game.add_sparkles(0)
	var sparkles_before: int = game.sparkles
	check(races.start("lake_loop"), "a new race")
	await _physics(200)
	for r in races.rivals:
		r.d = -30.0                                       # the friends hang back so this run wins
		r.speed = 0.0
		r.skill = 0.0
	# Skipping ahead to a later ring doesn't count
	_back_on_track(p, t, t.cp_dist[4] + 0.5)
	await _physics(3)
	check(races.next_cp == 1, "riding through a later ring doesn't count (next is still 1)")
	var laps: int = races.TRACKS.lake_loop.laps
	for lap in laps:
		for i in range(1, t.cp_dist.size() + 1):
			var cp: int = i % t.cp_dist.size()
			_back_on_track(p, t, t.cp_dist[cp] - 2.5)
			await _physics(2)
			_back_on_track(p, t, t.cp_dist[cp] + 1.0)
			await _physics(2)
		if lap < laps - 1:
			check(races.lap == lap + 2, "lap %d counted" % (lap + 2))
	check(races.state == races.State.RESULTS, "over the line after %d laps: finished" % laps)
	check(races.place == 1 and races.hud.results.visible, "you won, and the results are up")
	var prize: int = races.TRACKS.lake_loop.prizes[0]
	check(game.sparkles - sparkles_before == prize, "1st pays ✦ %d (got %d)" % [prize, game.sparkles - sparkles_before])
	check(races.best.has("lake_loop") and int(races.wins.get("lake_loop", 0)) == 1, "best time and the win are kept")
	check(not t.board_text.text.contains("not yet"), "the board shows the best time")
	check(not t.rings[1].visible, "the rings go away")
	await _physics(int(races.RESULTS_TIME * 60) + 10)
	check(not races.racing() and races.rivals.is_empty(), "after the results the friends ride home")
	var dash_home := false
	for r in town.find_children("Routine", "", true, false):
		if r.get("character_id") == "dash":
			dash_home = (r.get_parent() as Node3D).visible
	check(dash_home, "...and Dash is back in his usual place")

	# --- More tracks open one after another, and any starter can whizz you to them ---
	check(races.unlocked("meadow_wiggle") and not races.unlocked("observatory_hill"),
		"finishing the Lake Loop opens the Meadow Wiggle (the Observatory Hill waits for that)")
	var picks: Array = races.lines("lake_loop").filter(func(l) -> bool: return l is Dictionary and l.has("choice"))[0].choice
	check(picks.any(func(c: Dictionary) -> bool: return c.get("set", "") == "race_go_meadow_wiggle")
		and not picks.any(func(c: Dictionary) -> bool: return c.get("set", "") == "race_go_observatory_hill"),
		"Zippy offers to whizz you to the Meadow Wiggle, not the locked one")
	check(not races.start("observatory_hill"), "a locked track doesn't start")
	dialogue.flags["race_go_meadow_wiggle"] = true
	dialogue.finished.emit("race_starter")
	await _frames(2)
	var mw: Node3D = races.track_node("meadow_wiggle")
	check(races.racing() and races.track_id == "meadow_wiggle" and p.global_position.distance_to(mw.point_at(-4.0)) < 4.0,
		"picking it puts you on the Meadow Wiggle's grid")
	check(races.rivals.map(func(r) -> String: return r.id) == ["rook", "pip", "green_man"], "...against Rook, Pip and the Green Man")
	check(mw.rings[1].visible and not t.rings[1].visible, "...with its own rings out, not the Lake Loop's")
	races._end(false)
	await _physics(2)

	# --- A best time pays a bonus; slower doesn't ---
	sparkles_before = game.sparkles
	var old_best: float = races.best.lake_loop
	races.best.lake_loop = 999.0
	races.start("lake_loop")
	await _physics(200)
	for r in races.rivals:
		r.d = races.progress + 10.0                      # everyone ahead: you'll be 4th
		r.finished = true
	races.lap = laps
	races.last_cp = t.cp_dist.size() - 1
	races.next_cp = 0
	_back_on_track(p, t, t.length - 2.0)
	await _physics(2)
	_back_on_track(p, t, 1.0)
	await _physics(2)
	var fourth: int = races.TRACKS.lake_loop.prizes[3]
	check(races.place == 4 and game.sparkles - sparkles_before == fourth + races.BEST_BONUS,
		"4th still wins ✦ %d, plus ✦ %d for a best time (got %d)" % [fourth, races.BEST_BONUS, game.sparkles - sparkles_before])
	races._end(true)
	races.best.lake_loop = old_best

	# --- Stepping off ends it, no harm done ---
	races.start("lake_loop")
	await _physics(200)
	game.riding = false
	game.equipment_changed.emit()
	await _physics(3)
	check(not races.racing() and races.rivals.is_empty() and not p.input_locked, "stepping off your ride ends the race")
	game.riding = true
	game.equipment_changed.emit()
	await _physics(3)

	# --- Riding as Dash: someone else takes his place in the race ---
	p.set_rider("dash")
	await _physics(3)
	races.start("lake_loop")
	await _frames(2)
	var ids: Array = races.rivals.map(func(r) -> String: return r.id)
	check(not "dash" in ids and ids.size() == 3, "racing as Dash, a friend takes his place (%s)" % ", ".join(ids))
	races._end(false)
	p.set_rider("hero", false)

	# --- Zippy's Tune-Up: ride upgrades through the shared shop ---
	var shop := root.get_node("Shop")
	check(t.get_node_or_null("Tune-Up") != null and t.get_node("Tune-Up").find_child("Tune-Up Spot", true, false) != null,
		"Zippy's Tune-Up stands past the race board")
	check(t.get_node("Tune-Up").global_position.distance_to(t.point_at(-15.0)) > 6.0, "...off the track")
	var tune: Array = shop.items.values().filter(func(i: Dictionary) -> bool: return i.stall == "Tune-Up")
	check(tune.size() == 13, "it sells 4 upgrades in 3 levels and the Starter Star (%d)" % tune.size())
	check(shop.for_stall("Tune-Up").size() == 5, "...showing just the next level of each (%d)" % shop.for_stall("Tune-Up").size())
	game.sparkles = 200
	check(shop.can_buy("tune_wheels_2") != "", "level 2 waits for level 1 (%s)" % shop.can_buy("tune_wheels_2"))
	var base_push: float = s.ride.push_speed
	check(shop.buy("tune_wheels_1") and races.level("wheels") == 1, "buying Speedy Wheels I")
	check(absf(float(s.ride.push_speed) - base_push * 1.05) < 0.01, "...makes the ride faster (%.2f -> %.2f)" % [base_push, s.ride.push_speed])
	check(shop.can_buy("tune_wheels_1") == "You have this one" and shop.can_buy("tune_wheels_2") == "", "...and level 2 is next")
	check(shop.for_stall("Tune-Up").any(func(i: Dictionary) -> bool: return i.id == "tune_wheels_2")
		and not shop.for_stall("Tune-Up").any(func(i: Dictionary) -> bool: return i.id == "tune_wheels_1"), "...in level 1's place on the bench")
	shop.buy("tune_wheels_2")
	shop.buy("tune_grip_1")
	check(absf(float(s.ride.push_speed) - base_push * 1.10) < 0.01 and float(s.ride.carve) > float(Rides.ride("hero").carve) * 1.1,
		"level 2 adds more, and Grippy Grip turns sharper")
	p.set_rider("dash")
	await _physics(2)
	var dash_push: float = Rides.ride("dash").push_speed
	check(absf(float(s.ride.push_speed) - dash_push * 1.10) < 0.01, "upgrades work on a friend's ride too (Dash %.2f)" % s.ride.push_speed)
	p.set_rider("hero", false)
	await _physics(2)
	shop.buy("tune_turbo_1")
	check(absf(races.boost_time(2.0) - 2.5) < 0.01, "Turbo Tank makes boosts last longer")
	shop.buy("tune_starter_star")
	races.start("lake_loop")
	await _frames(2)
	check(races.power == "zoom" and races.hud.power_box.visible, "with the Starter Star every race starts with a Zoom Star")
	races._end(false)

	# --- Saved ---
	var data: Dictionary = races.save_data()
	races.reset()
	races.load_data(data)
	check(races.best.has("lake_loop") and int(races.wins.lake_loop) == 1, "best times and wins load back")
	check(races.level("wheels") == 2 and races.level("starter") == 1, "...and the upgrades")
	var plain: float = Rides.ride("hero").push_speed
	races.reset()
	check(races.level("wheels") == 0 and absf(float(s.ride.push_speed) - plain) < 0.01, "a new game starts with no upgrades")

	_finish()


func _check_track(id: String, t: Node3D, p: CharacterBody3D) -> void:
	var tr: Dictionary = races.TRACKS[id]
	var L: float = t.length
	check(L > 120.0 and L < 400.0, "%s: a lap is a good length (%.0f m)" % [tr.name, L])
	check(t.cp_dist.size() == tr.points.size(), "%s: a ring for every checkpoint (%d)" % [tr.name, t.cp_dist.size()])
	var wet := 0
	var steep := 0
	var steep_at: Array[String] = []
	var blocked: Array[String] = []
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var near_portal := INF
	for i in t.line.size():
		var a: Vector3 = t.line[i]
		var b: Vector3 = t.line[(i + 1) % t.line.size()]
		if a.y < -0.55:                                   # under the lake's water (tools/build_town.gd, WATER_Y)
			wet += 1
		var run := Vector2(b.x - a.x, b.z - a.z).length()
		if b.y - a.y > 0.32 and (b.y - a.y) / maxf(run, 0.01) > 0.7:
			steep += 1
			steep_at.append("(%.0f, %.0f) %.2f m" % [a.x, a.z, b.y - a.y])
		near_portal = minf(near_portal, Vector2(a.x, a.z).distance_to(PORTAL))
		# Anything across the line at knee and chest height, for every lane a racer might use
		for side in [-2.2, 0.0, 2.2]:
			# (each lane on the ground under it, so a hill that slopes across the track isn't a wall)
			var off: Vector3 = t.side_at(t.dist[i]) * side
			var la: Vector3 = t.ground_at(Vector2(a.x + off.x, a.z + off.z))
			var lb: Vector3 = t.ground_at(Vector2(b.x + off.x, b.z + off.z))
			for h in [0.6, 1.3]:
				var q := PhysicsRayQueryParameters3D.create(la + Vector3.UP * h, lb + Vector3.UP * (h + maxf(lb.y - la.y, 0.0)))
				q.exclude = [p.get_rid()]
				var hit: Dictionary = space.intersect_ray(q)
				if not hit.is_empty() and hit.collider is StaticBody3D and blocked.size() < 8:
					blocked.append("%s/%s at (%.0f, %.0f) lane %+.0f" % [(hit.collider as Node).get_parent().name, (hit.collider as Node).name, a.x, a.z, side])
	check(wet == 0, "%s: the whole line is on dry ground (%d points in water)" % [tr.name, wet])
	check(steep == 0, "%s: no steps too high to roll up (%s)" % [tr.name, ", ".join(steep_at)])
	check(blocked.is_empty(), "%s: nothing in the way, in any lane (%s)" % [tr.name, ", ".join(blocked)])
	check(near_portal > 6.5, "%s: the line stays clear of the portal (%.1f m)" % [tr.name, near_portal])
	var who := str(tr.starter.name)
	var st := t.get_node_or_null(who) as Node3D
	check(st != null and t.get_node_or_null("Race Board") != null, "%s: %s and the race board are by the line" % [tr.name, who])
	if st:
		check(st.global_position.distance_to(t.point_at(0.0)) > 6.0 and st.global_position.y > -0.3,
			"%s: %s stands off the track, on dry ground" % [tr.name, who])
	# Nothing of this track sits on another track's line
	for other in races.TRACKS:
		if other == id:
			continue
		var o: Node3D = races.track_node(other)
		var close := INF
		for n in [st, t.get_node("Race Board"), t.get_node("Start Arch")]:
			close = minf(close, o.off_line(n.global_position, o.nearest(n.global_position)))
		check(close > 5.0, "%s: its start is clear of the %s (%.1f m)" % [tr.name, races.TRACKS[other].name, close])
	await physics_frame


func _back_on_track(p: CharacterBody3D, t: Node3D, d: float) -> void:
	p.global_position = t.point_at(d) + Vector3.UP * 0.85
	p.velocity = t.dir_at(d) * 6.0


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

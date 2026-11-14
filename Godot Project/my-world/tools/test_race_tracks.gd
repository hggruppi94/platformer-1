extends SceneTree

# Checks the circuits' secret shortcuts, tunnels and moving obstacles (Hayden's 13 Nov 2026 playtest: "The races need
# a lot of work; moving maps, obstacles, secret shortcuts, tunnels"):
#
#   - Every circuit has a secret shortcut: a gap in the wall on the inside of a bend, behind a curtain of vines (or
#     cornstalks), into a tunnel across the middle and back out further round. It stays clear of the road in the
#     middle, nothing's in the way at its mouths, it never crosses the start line, it has a floor and a roof.
#   - Riding through it from the right bit of the lap moves you on past the rings it skips, the first time pays
#     sparkles and the board says so; going in the wrong end gets you nothing.
#   - Every circuit has a tunnel over the road, clear of the shortcut's mouths and of ramps, and the racing line still
#     runs along the road under it (not over the roof).
#   - Sliders glide across the road and bounce you off; pop-up walls glow, come up, bounce you back and go down again;
#     the friends steer round both.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_race_tracks.gd
#
# Your own save and settings are put aside (under names of their own) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.race_tracks_backup.json"
const SETTINGS := "user://settings.cfg"
const TOWN := "res://scenes/town/town.tscn"
const SETTINGS_BACKUP := "user://settings.race_tracks_backup.cfg"

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
	dialogue = root.get_node("Dialogue")
	races = root.get_node("Races")
	settings.use_layout("classic")
	settings.tips = false
	settings.race_intros = false
	settings.skate_assist = 0
	game._resume = {}
	game.pending_message = ""
	game.riding = false
	game.hold_saves = true
	races.reset()
	races.raced = 3
	for f in dialogue.flags.keys():
		if str(f).begins_with("race_"):
			dialogue.flags.erase(f)
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	root.get_node("Clock").set("pulls_home", false)
	for k in races.TRACKS:
		if races.TRACKS[k].has("circuit"):
			races.finished_once[k] = true

	# --- The data: every circuit has one of each, in sensible places ---
	for id in races.TRACKS:
		var tr: Dictionary = races.TRACKS[id]
		if not tr.has("circuit"):
			continue
		var n: int = tr.points.size()
		check(tr.get("shortcuts", []).size() == 1 and tr.get("tunnels", []).size() == 1, "%s has a secret shortcut and a tunnel" % tr.name)
		var kinds: Array = tr.obstacles.map(func(o: Array) -> String: return str(o[1]))
		check("slider" in kinds and "popup" in kinds, "%s has a slider and a pop-up wall" % tr.name)
		for sc in tr.get("shortcuts", []):
			check(float(sc.from) >= 1.0 and float(sc.to) < n - 1.0 and floor(float(sc.from)) < floor(float(sc.to)),
				"%s: its shortcut skips rings and never crosses the start line (%.1f to %.1f)" % [tr.name, sc.from, sc.to])
		for tn in tr.get("tunnels", []):
			var ramps: Array = tr.obstacles.filter(func(o: Array) -> bool: return str(o[1]) == "ramp" and o[0] > tn[0] - 0.1 and o[0] < tn[1] + 0.1)
			check(ramps.is_empty(), "%s: no ramp under its tunnel" % tr.name)
			for sc in tr.get("shortcuts", []):
				check(tn[1] < sc.from - 0.4 or tn[0] > sc.to + 0.4 or (tn[0] > sc.from + 0.4 and tn[1] < sc.to - 0.4),
					"%s: its tunnel keeps clear of the shortcut's mouths" % tr.name)

	# --- Each circuit, built: the shortcut's path, its walls, floor and roof, the tunnel over the road ---
	for id in races.TRACKS:
		var tr: Dictionary = races.TRACKS[id]
		if not tr.has("circuit"):
			continue
		change_scene_to_file(str(tr.scene))
		await _frames(4)
		var c: Node3D = current_scene
		# (A lambda can't set an outer variable, so look the track up again after waiting for it)
		await _until(func() -> bool:
			var tt: Node3D = races.track_node(id)
			return tt != null and tt.ready_to_race, 300)
		var t: Node3D = races.track_node(id)
		check(c.shortcuts.size() == 1, "%s: the shortcut's built" % tr.name)
		if c.shortcuts.is_empty() or t == null:
			continue
		var sc: Dictionary = c.shortcuts[0]
		var path: Array = sc.path
		var hw: float = c.half_width()
		var worst := INF
		for i in range(path.size() / 4, path.size() * 3 / 4):
			worst = minf(worst, c.off_road(Vector2(path[i].x, path[i].z)))
		check(worst > hw + c.WALL_T + c.SC_HALF + 0.5, "%s: the shortcut's middle half keeps clear of the road (%.1f m from its middle)" % [tr.name, worst])
		check(float(sc.length) < float(sc.d1) - float(sc.d0) - 25.0,
			"%s: it's a real shortcut (%.0f m against %.0f m round the road)" % [tr.name, sc.length, float(sc.d1) - float(sc.d0)])
		var bad: Array[String] = []
		for o in tr.obstacles + tr.get("goo", []):
			var od: float = t.at(float(o[0]))
			for m in [float(sc.d0), float(sc.d1)]:
				if absf(od - m) < 14.0:
					bad.append(str(o))
		check(bad.is_empty(), "%s: nothing in the way at the shortcut's mouths (%s)" % [tr.name, ", ".join(bad)])
		var opened := 0
		for k in c._open:
			opened += 1
		check(opened >= 6, "%s: the road's wall is open at both mouths (%d points)" % [tr.name, opened])
		var holder := c.get_node_or_null("Shortcut 0")
		check(holder != null and holder.get_node_or_null("Curtain") != null and holder.get_node_or_null("Curtain 2") != null,
			"%s: a curtain hides each end" % tr.name)
		if holder:
			check(holder.get_node("Curtain").find_children("*", "CollisionObject3D", true, false).is_empty(), "...and you ride straight through it")
		# Floor under the middle, roof over it
		var mid: Vector3 = path[path.size() / 2]
		var space := c.get_world_3d().direct_space_state
		var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(mid + Vector3.UP * 2.0, mid + Vector3.DOWN * 3.0))
		check(not down.is_empty() and absf(down.position.y - mid.y) < 0.2, "%s: the shortcut has a floor" % tr.name)
		var up := space.intersect_ray(PhysicsRayQueryParameters3D.create(mid + Vector3.UP * 1.0, mid + Vector3.UP * 12.0))
		check(not up.is_empty() and up.position.y > mid.y + 4.0, "%s: ...and a tunnel roof over it" % tr.name)
		# The road tunnel: the racing line runs along the road under it, not over its roof
		var tn: Array = tr.tunnels[0]
		var td: float = t.at((float(tn[0]) + float(tn[1])) / 2.0)
		var under: Vector3 = t.point_at(td)
		var road_y: float = c.line[c.index_at(c.d_at((float(tn[0]) + float(tn[1])) / 2.0))].y
		check(absf(under.y - road_y) < 0.5, "%s: under its tunnel the racing line is on the road (%.1f, road %.1f)" % [tr.name, under.y, road_y])
		var roof := space.intersect_ray(PhysicsRayQueryParameters3D.create(under + Vector3.UP * 1.0, under + Vector3.UP * 14.0))
		check(not roof.is_empty() and roof.position.y > under.y + 7.5, "%s: ...and the tunnel's roof is high over the rings" % tr.name)

	# --- Racing through the Lake Loop's shortcut, from Zippy's gate as a player would ---
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
	var c: Node3D = current_scene
	var sc: Dictionary = c.shortcuts[0]
	check(races.board_text("lake_loop").contains("Secret shortcut: ???"), "the board says there's a secret shortcut to find")
	check(str(races.hub_lines("void")).contains("secret shortcut"), "...and Zippy drops a hint")
	# Ride round to just before the mouth (past the ring before it, as if you'd raced there)
	races.last_cp = int(floor(float(sc.from)))
	races.next_cp = races.last_cp + 1
	races._along = -1.0
	var before: int = game.sparkles
	await _ride(p, sc.path, 0, sc.path.size() - 1)
	check(races.state == races.State.RACING, "through the shortcut, the race is still on (nobody popped you back)")
	check(races.last_cp == int(floor(float(sc.to))) and races.next_cp == int(floor(float(sc.to))) + 1,
		"...and you're on past the rings it skipped (last %d, next %d)" % [races.last_cp, races.next_cp])
	check(dialogue.flags.has("race_shortcut_lake_loop_0") and game.sparkles == before + races.SHORTCUT_PRIZE,
		"the first time pays %d sparkles" % races.SHORTCUT_PRIZE)
	check(races.board_text("lake_loop").contains("Secret shortcut: found!"), "...and the board says it's found")
	# Out onto the road and on to the next ring like anyone else
	var after: Vector3 = sc.path[sc.path.size() - 1]
	var d1: float = float(sc.d1)
	await _ride_road(p, t, d1, t.cp_dist[races.next_cp] + 2.0)
	check(races.last_cp == int(floor(float(sc.to))) + 1, "...then on through the next ring as usual")
	# The wrong way in: no credit
	races.last_cp = 9
	races.next_cp = 10
	var lc: int = races.last_cp
	await _ride(p, sc.path, sc.path.size() - 6, sc.path.size() / 2)
	check(races.last_cp == lc, "in at the far end, it doesn't move you on")
	races._sc = -1

	# --- Moving obstacles ---
	var slider: Node3D = null
	var popup: Node3D = null
	for o in t.obstacles:
		if str(o.get_meta("kind")) == "slider":
			slider = o
		elif str(o.get_meta("kind")) == "popup":
			popup = o
	check(slider != null and popup != null, "the slider and the pop-up wall are on the track")
	var s0: float = slider.get_meta("side")
	await _frames(20)
	var s1: float = slider.get_meta("side")
	check(absf(s1 - s0) > 0.05, "the slider glides across the road (%.1f -> %.1f)" % [s0, s1])
	var puck := slider.get_node("Puck") as Node3D
	var puck_world := puck.global_position
	var road_side: Vector3 = t.point_at(float(slider.get_meta("d"))) + t.side_at(float(slider.get_meta("d"))) * s1
	check(Vector2(puck_world.x, puck_world.z).distance_to(Vector2(road_side.x, road_side.z)) < 1.0, "...and it's where the friends think it is")
	p.global_position = puck.global_position + t.dir_at(float(slider.get_meta("d"))) * -1.2 + Vector3.UP * 0.9
	p.velocity = t.dir_at(float(slider.get_meta("d"))) * 8.0
	races.attacks._bump_wait = 0.0
	races.attacks._tick_obstacles(t)
	check(p.velocity.dot(t.dir_at(float(slider.get_meta("d")))) < 8.0, "riding into it bounces you off")
	# Pop-up wall: wait for it to be up
	await _until(func() -> bool: return t.pop_up(popup), 400)
	await _until(func() -> bool: return (popup.get_node("Wall") as Node3D).position.y > -0.5, 60)
	check(t.pop_up(popup) and (popup.get_node("Wall") as Node3D).position.y > -0.5, "the pop-up wall comes up out of the road")
	var pd: float = popup.get_meta("d")
	p.global_position = popup.global_position - t.dir_at(pd) * 0.8 + Vector3.UP * 0.9
	p.velocity = t.dir_at(pd) * 8.0
	races.attacks._bump_wait = 0.0
	races.attacks._tick_obstacles(t)
	check(p.velocity.dot(t.dir_at(pd)) < 0.0, "riding into it while it's up bounces you back")
	await _until(func() -> bool: return not t.pop_up(popup) and not t.pop_warning(popup), 400)
	p.global_position = popup.global_position - t.dir_at(pd) * 0.8 + Vector3.UP * 0.9
	p.velocity = t.dir_at(pd) * 8.0
	races.attacks._bump_wait = 0.0
	races.attacks._tick_obstacles(t)
	check(p.velocity.dot(t.dir_at(pd)) > 7.0, "...and when it's down you ride straight over it")
	await _until(func() -> bool: return t.pop_warning(popup), 400)
	check((popup.get_node("Glow") as Node3D).visible, "its patch of road glows before it comes up")
	# The friends steer round it while it's up or about to be
	var r = races.rivals[0]
	r.d = fposmod(pd - 8.0, t.length)
	r.lane = 0.0
	r.lane_goal = 0.0
	races.attacks._rival_steer(r, t)
	check(absf(r.lane_goal) > t.POP_HALF, "a friend coming up to it picks a lane round it (%.1f)" % r.lane_goal)
	races._end(false)
	_finish()


func _ride(p: CharacterBody3D, path: Array, from: int, to: int) -> void:
	# Along a shortcut's floor a metre a frame or so, as if riding it
	var step := 1 if to > from else -1
	var i := from
	while i != to:
		var a: Vector3 = path[i]
		var b: Vector3 = path[clampi(i + step, 0, path.size() - 1)]
		p.global_position = a + Vector3.UP * 0.9
		p.velocity = (b - a).normalized() * 10.0
		await physics_frame
		i += step


func _ride_road(p: CharacterBody3D, t: Node3D, from: float, to: float) -> void:
	var d := from
	while d < to:
		p.global_position = t.point_at(d) + Vector3.UP * 0.9
		p.velocity = t.dir_at(d) * 10.0
		await physics_frame
		d += 0.8


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
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	print("RESULT %s (%d failed)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures > 0 else 0)

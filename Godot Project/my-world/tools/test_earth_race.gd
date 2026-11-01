extends SceneTree

# Checks the Pumpkin Run, the race round Stars Hollow on Earth (scripts/races.gd TRACKS "pumpkin_run"): it's placed in
# the Earth town at play time, its line is on dry ground with nothing in the way in any lane and no step too high,
# it stays clear of the old oak's portal, Pepper (an Earth kid made like the townsfolk) and the race board stand off
# the track, it's open from the start, the friends who race are Earth kids from town (Nina, Bruno and Ozzie, copied
# from the townsfolk, on their own rides) and step out of their usual places while they race, and a whole race
# finishes and pays out.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_earth_race.gd
#
# Your own save and settings are put aside (under names of their own) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.earth_race_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.earth_race_backup.cfg"
const EARTH := "res://scenes/earth/earth.tscn"
const PORTAL := Vector2(-10, 10)                  # the old oak and its portal (tools/build_earth.gd PORTAL_AT)

var failures := 0
var game: Node
var settings: Node
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
	races = root.get_node("Races")
	settings.use_layout("classic")
	settings.last_device = "keyboard"
	settings.tips = false
	settings.skate_assist = 1
	settings.set("race_intros", false)
	game._resume = {}
	game.pending_message = ""
	game.riding = false
	races.reset()
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.day = 1                                      # a Friday, so the Autumn Festival isn't on the green
	clock.set_earth_time(14 * 60.0, true)              # an afternoon on Earth, well away from the Shift

	change_scene_to_file(EARTH)
	await _frames(8)
	var earth := current_scene
	var p := earth.find_child("Player", true, false) as CharacterBody3D
	var t: Node3D = races.track_node("pumpkin_run")
	check(t != null, "the Pumpkin Run is placed in Stars Hollow at play time")
	if t == null:
		_finish()
		return
	for k in 30:
		if t.ready_to_race:
			break
		await physics_frame
	check(t.ready_to_race, "...and its racing line is worked out")
	check(races.track_node("lake_loop") == null, "Galaxity's tracks aren't put on Earth")
	check(races.unlocked("pumpkin_run"), "it's open from the start (it's at home)")
	await _check_line(t, p)

	# Pepper, the board and the arch
	var st := t.get_node_or_null("Pepper") as Node3D
	check(st != null and t.get_node_or_null("Race Board") != null and t.get_node_or_null("Start Arch") != null,
		"Pepper, the race board and the start arch are by the line")
	if st:
		check(st.global_position.distance_to(t.point_at(0.0)) > 6.0, "Pepper stands off the track")
		check(st.find_children("*", "Townsfolk", true, false).size() == 1 or st.get_child(0) is Townsfolk,
			"...and she's an Earth kid, not a little alien")
	var lines: Array = races.lines("pumpkin_run")
	check(str(lines).contains("Pepper") and not str(lines).contains("Sky Rings") and not str(lines).contains("Zippy"),
		"Pepper talks about her own race, not Galaxity's")
	check(lines.any(func(l) -> bool: return l is Dictionary and str(l.get("choice", "")).contains("race_go_pumpkin_run")),
		"...and asks if you're ready")

	# A race: three Earth kids line up
	var nina := _townsfolk(earth, "nina_earth")
	check(races.start("pumpkin_run"), "saying yes starts the race")
	check(races.rivals.map(func(r) -> String: return r.id) == ["nina_earth", "bruno", "ozzie"],
		"...against Nina, Bruno and Ozzie (%s)" % ", ".join(races.rivals.map(func(r) -> String: return r.id)))
	var r0: Node = races.rivals[0]
	check(r0.find_children("*", "Townsfolk", true, false).size() > 0, "the friends are Earth kids (made like the townsfolk)")
	check(r0.display_name() == "Nina" and races.rivals[1].display_name() == "Bruno", "...called by their Earth names")
	check(races.rivals[1].find_child("Ride", true, false).get_child_count() > 0, "...on their rides")
	check(nina != null and not nina.visible, "Nina steps out of her usual place while she races")
	var held: Array = r0.find_children("skateboard", "", true, false)
	check(held.is_empty(), "...and the board she carries round town is under her feet, not in her hand")
	await _physics(int(races.COUNTDOWN * 60) + 10)
	check(races.state == races.State.RACING, "GO: the race is on")
	await _physics(120)
	var moved: float = races.rivals[0].d + 9.0
	check(moved > 6.0 and moved < 30.0, "the friends ride round at a fair pace (%.1f m in 2 s)" % moved)

	# Round the rings: two laps
	var laps := int(races.TRACKS.pumpkin_run.laps)
	for lap in laps:
		for i in range(1, t.cp_dist.size() + 1):
			var d: float = t.cp_dist[i % t.cp_dist.size()]
			p.global_position = t.point_at(d - 2.0) + Vector3.UP * 0.85
			p.velocity = t.dir_at(d) * 7.0
			await _physics(4)
			p.global_position = t.point_at(d) + Vector3.UP * 0.85
			await _physics(3)
			if races.state != races.State.RACING:
				break
	check(races.state == races.State.RESULTS, "two laps and it's finished")
	check(races.best.has("pumpkin_run"), "...and the best time is kept")
	check(races.hud.results.visible and str(races.hud.results_label.text).contains("Bruno"), "the results name the Earth kids")
	await _physics(int(races.RESULTS_TIME * 60) + 20)
	check(not races.racing() and nina.visible, "after the results Nina's back in her usual place")
	_finish()


func _check_line(t: Node3D, p: CharacterBody3D) -> void:
	var tr: Dictionary = races.TRACKS.pumpkin_run
	var L: float = t.length
	check(L > 120.0 and L < 420.0, "a lap is a good length (%.0f m)" % L)
	var wet := 0
	var steep_at: Array[String] = []
	var blocked: Array[String] = []
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var near_portal := INF
	for i in t.line.size():
		var a: Vector3 = t.line[i]
		var b: Vector3 = t.line[(i + 1) % t.line.size()]
		if EarthLand.is_water(a.x, a.z) or a.y < EarthLand.WATER_Y:
			wet += 1
		var run := Vector2(b.x - a.x, b.z - a.z).length()
		if b.y - a.y > 0.32 and (b.y - a.y) / maxf(run, 0.01) > 0.7 and steep_at.size() < 8:
			steep_at.append("(%.0f, %.0f) %.2f m" % [a.x, a.z, b.y - a.y])
		near_portal = minf(near_portal, Vector2(a.x, a.z).distance_to(PORTAL))
		for side in [-2.2, 0.0, 2.2]:
			var off: Vector3 = t.side_at(t.dist[i]) * side
			var la: Vector3 = t.ground_at(Vector2(a.x + off.x, a.z + off.z))
			var lb: Vector3 = t.ground_at(Vector2(b.x + off.x, b.z + off.z))
			for h in [0.6, 1.3]:
				var q := PhysicsRayQueryParameters3D.create(la + Vector3.UP * h, lb + Vector3.UP * (h + maxf(lb.y - la.y, 0.0)))
				q.exclude = [p.get_rid()]
				var hit: Dictionary = space.intersect_ray(q)
				if not hit.is_empty() and hit.collider is StaticBody3D and blocked.size() < 12:
					blocked.append("%s/%s at (%.0f, %.0f) lane %+.0f" % [(hit.collider as Node).get_parent().name, (hit.collider as Node).name, a.x, a.z, side])
	check(wet == 0, "the whole line is on dry ground (%d points in water)" % wet)
	check(steep_at.is_empty(), "no steps too high to roll up (%s)" % ", ".join(steep_at))
	check(blocked.is_empty(), "nothing in the way, in any lane (%s)" % ", ".join(blocked))
	check(near_portal > 6.5, "the line stays clear of the old oak's portal (%.1f m)" % near_portal)
	var bounds := Rect2(-152, -152, 244, 254).grow(-6.0)
	var outside := 0
	for a in t.line:
		if not bounds.has_point(Vector2(a.x, a.z)):
			outside += 1
	check(outside == 0, "...and inside the town's walls (%d outside)" % outside)
	await physics_frame


func _townsfolk(scene: Node, id: String) -> Node3D:
	for r in scene.find_children("Routine", "", true, false):
		if r.get("character_id") == id:
			return r.get_parent() as Node3D
	return null


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

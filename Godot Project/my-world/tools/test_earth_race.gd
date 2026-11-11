extends SceneTree

# Checks the Pumpkin Run, Stars Hollow's race (scripts/races.gd TRACKS "pumpkin_run"). Since Nov 11, 2026 it's a
# circuit of its own (scenes/races/pumpkin_run.tscn, laid out by scripts/race_circuit.gd): in town there's only Pepper's
# race gate (the arch, Pepper and the board), on dry ground, clear of the old oak and of everyone's paths. Saying yes
# takes you to the farm-lane circuit, where six Earth kids from town race you (copied from the townsfolk, so they look
# like themselves), three laps round, and going back puts you by the gate in Stars Hollow again.
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
	create_timer(400.0, true, false, true).timeout.connect(func() -> void:
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
	clock.calendar_offset = clock.CALENDAR_START           # (the calendar as a new game has it, whatever the save said)
	clock.day = 1                                      # a Friday, so the Autumn Festival isn't on the green
	clock.set_earth_time(14 * 60.0, true)              # an afternoon on Earth, well away from the Shift

	change_scene_to_file(EARTH)
	await _frames(8)
	var earth := current_scene
	var p := earth.find_child("Player", true, false) as CharacterBody3D
	check(races.track_node("pumpkin_run") == null, "the Pumpkin Run isn't laid out round town any more")
	var gate: Node3D = races.hub_node("earth")
	check(gate != null, "Pepper's race gate is put up in Stars Hollow at play time")
	if gate == null:
		_finish()
		return
	await _until(func() -> bool: return gate.ready_to_race, 60)
	check(races.hub_node("void") == null, "Zippy's gate isn't put on Earth")
	check(races.unlocked("pumpkin_run"), "it's open from the start (it's at home)")
	await _check_gate(gate, p)
	var st := gate.get_node_or_null("Pepper") as Node3D
	check(st != null and gate.get_node_or_null("Race Board") != null and gate.get_node_or_null("Start Arch") != null,
		"Pepper, the race board and the arch are at the gate")
	if st:
		check(st.find_children("*", "Townsfolk", true, false).size() == 1 or st.get_child(0) is Townsfolk,
			"...and she's an Earth kid, not a little alien")
	var lines: Array = races.hub_lines("earth")
	check(str(lines).contains("Pepper") and not str(lines).contains("Sky Rings") and not str(lines).contains("Zippy"),
		"Pepper talks about her own race, not the Void's")
	var choice: Array = []
	for l in lines:
		if l is Dictionary and l.has("choice"):
			choice = l.choice
	check(choice.any(func(c: Dictionary) -> bool: return c.get("set", "") == "race_go_pumpkin_run"), "...and asks if you're ready")
	check(choice.size() == 2, "...and only offers her own race (and \"not now\")")

	# Off to the circuit
	var nina := _townsfolk(earth, "nina_earth")
	var from: Vector3 = p.global_position
	check(races.enter_circuit("pumpkin_run"), "saying yes takes you to the Pumpkin Run")
	var path: String = races.TRACKS.pumpkin_run.scene
	await _until(func() -> bool: return current_scene != null and current_scene.scene_file_path == path, 240)
	await _until(func() -> bool: return races.racing(), 240)
	check(current_scene.scene_file_path == path and races.racing(), "...its own circuit, and the race starts by itself")
	p = current_scene.find_child("Player", true, false) as CharacterBody3D
	var t: Node3D = races.track_node("pumpkin_run")
	check(t != null and t.earth, "the track has Earth's look (hay bales and windmills, not crystals)")
	var ids: Array = races.rivals.map(func(r) -> String: return r.id)
	check(ids == ["nina_earth", "bruno", "ozzie", "juniper", "theo", "prue"], "six Earth kids race you (%s)" % ", ".join(ids))
	var r0: Node = races.rivals[0]
	check(r0.find_children("*", "Townsfolk", true, false).size() > 0, "the friends are Earth kids (made like the townsfolk)")
	check(r0.display_name() == "Nina" and races.rivals[1].display_name() == "Bruno", "...called by their Earth names")
	if nina:
		var copy := r0.find_children("*", "Townsfolk", true, false)[0] as Townsfolk
		check(copy.look.get("colors", {}) == (nina as Townsfolk).look.get("colors", {}), "...and Nina looks just like she does in town")
	check(races.rivals[1].find_child("Ride", true, false).get_child_count() > 0, "...on their rides")
	var held: Array = r0.find_children("skateboard", "", true, false)
	check(held.is_empty(), "...and the board she carries round town is under her feet, not in her hand")
	await _physics(int(races.COUNTDOWN * 60) + 10)
	check(races.state == races.State.RACING, "GO: the race is on")
	await _physics(120)
	check(races.rivals.all(func(r) -> bool: return r.d > -16.0), "everyone sets off (%s)" % ", ".join(races.rivals.map(func(r) -> String: return "%.0f" % r.d)))

	# Round the rings: three laps
	for r in races.rivals:
		r.d = -80.0
		r.speed = 0.0
		r.skill = 0.0
	races.attacks._aim_wait = 999.0
	var laps := int(races.TRACKS.pumpkin_run.laps)
	check(laps == 3, "three laps")
	for lap in laps:
		for i in range(1, t.cp_dist.size() + 1):
			var d: float = t.cp_dist[i % t.cp_dist.size()]
			p.global_position = t.point_at(d - 2.5) + Vector3.UP * 0.9
			p.velocity = t.dir_at(d) * 6.0
			await _physics(2)
			p.global_position = t.point_at(d + 1.0) + Vector3.UP * 0.9
			await _physics(2)
			if races.state != races.State.RACING:
				break
	check(races.state == races.State.RESULTS, "three laps and it's finished")
	check(races.best.has("pumpkin_run"), "...and the best time is kept")
	check(races.hud.results.visible and str(races.hud.results_label.text).contains("Bruno"), "the results name the Earth kids")
	check(races.hud.choosing() and str((races.hud.choice_box.get_child(1) as Button).text).contains("Stars Hollow"),
		"...with a button back to Stars Hollow")
	(races.hud.choice_box.get_child(1) as Button).pressed.emit()
	await _until(func() -> bool: return current_scene != null and current_scene.scene_file_path == EARTH, 240)
	await _frames(4)
	check(current_scene.scene_file_path == EARTH and races.circuit == "", "back to Stars Hollow")
	p = current_scene.find_child("Player", true, false) as CharacterBody3D
	await _physics(10)
	check(p.global_position.distance_to(from) < 3.0, "...by Pepper's gate, where you set off (%.1f m)" % p.global_position.distance_to(from))
	_finish()


func _check_gate(gate: Node3D, p: CharacterBody3D) -> void:
	# The gate's spot: dry, flat, clear of the old oak, nothing built through it, off everyone's paths
	var hub: Dictionary = races.HUBS.earth
	var at: Vector2 = hub.at
	check(not EarthLand.is_water(at.x, at.y) and EarthLand.height(at.x, at.y) > EarthLand.WATER_Y + 0.3, "the gate's on dry ground")
	check(at.distance_to(PORTAL) > 12.0, "...well clear of the old oak (%.0f m)" % at.distance_to(PORTAL))
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var blocked: Array[String] = []
	for i in gate.line.size():
		var a: Vector3 = gate.line[i]
		var q := PhysicsRayQueryParameters3D.create(a + Vector3.UP * 0.6, a + Vector3.UP * 0.6 + gate.side_at(gate.dist[i]) * 0.01 + gate.dir_at(gate.dist[i]))
		q.exclude = [p.get_rid()]
		var hit: Dictionary = space.intersect_ray(q)
		if not hit.is_empty() and hit.collider is StaticBody3D and blocked.size() < 6:
			blocked.append("%s at (%.0f, %.0f)" % [(hit.collider as Node).name, a.x, a.z])
	check(blocked.is_empty(), "...and nothing stands in its way through the arch (%s)" % ", ".join(blocked))
	var bounds := Rect2(-152, -152, 244, 254).grow(-6.0)
	check(bounds.has_point(at), "...and it's inside the town's walls")
	await physics_frame


func _until(cond: Callable, frames: int) -> void:
	for i in frames:
		if cond.call():
			return
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

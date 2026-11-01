extends SceneTree

# Checks the gap bonuses (scripts/skate_gaps.gd): every named gap's skate pieces are found in its scene, a jump that
# fits a gap puts it in the combo (and one that doesn't, doesn't), "both" gaps count either way, the anywhere gaps
# (hang time, long gap, big drop, rail transfer) work and vert airs don't count as hang time, the first landing of a
# gap finds it (a flag and sparkles) and the next doesn't pay again, the gap is paid out with the combo, and real
# rides off the Hollow Skate Yard's gap kicker and the Big Air Kicker land their gaps.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_gaps.gd
#
# Your own save and settings are put aside (under names of their own) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.gaps_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.gaps_backup.cfg"
const EARTH := "res://scenes/earth/earth.tscn"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0
var game: Node
var gaps: Node
var dialogue: Node


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
	gaps = root.get_node("Gaps")
	dialogue = root.get_node("Dialogue")
	var settings := root.get_node("Settings")
	settings.use_layout("classic")
	settings.tips = false
	settings.skate_assist = 1
	game._resume = {}
	game.pending_message = ""
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	for id in gaps.all_ids():
		dialogue.flags.erase("gap_" + id)
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.day = 1
	clock.set_earth_time(14 * 60.0, true)

	change_scene_to_file(EARTH)
	await _frames(8)
	var p := current_scene.find_child("Player", true, false) as CharacterBody3D
	game.riding = true
	game.equipment_changed.emit()
	await _physics(4)
	var s: Node = p.get_node("Skate")
	var tricks = s.tricks

	# Every Earth gap is placed
	var earth_ids: Array = gaps.GAPS.keys().filter(func(id: String) -> bool: return gaps.GAPS[id].scene == EARTH)
	var placed: Array = earth_ids.filter(func(id: String) -> bool: return not gaps.zone(id).is_empty())
	check(placed.size() == earth_ids.size(), "every Earth gap's skate pieces are found (%d of %d)" % [placed.size(), earth_ids.size()])
	check(gaps.zone("park_funbox_hop").is_empty(), "Galaxity's gaps aren't looked for on Earth")
	check(gaps.all_ids().size() >= 10, "there are plenty of gaps to find (%d)" % gaps.all_ids().size())

	# A jump that fits: off the yard's gap kicker onto the landing deck
	var z: Array = gaps.zone("hollow_yard_gap")
	var sparkles: int = game.sparkles
	tricks.lose()
	var got: Array = gaps.check_landing(z[0], z[2], 0.9, false, false, false, null, null, s)
	check("hollow_yard_gap" in got, "kicker to landing deck: the Hollow Yard Gap")
	check(tricks.combo.size() == 1 and tricks.combo[0].name == "Hollow Yard Gap" and tricks.combo[0].points == 500,
		"...goes into the combo (%s)" % str(tricks.combo))
	check(gaps.is_found("hollow_yard_gap") and game.sparkles == sparkles + gaps.FIRST_SPARKLES, "...and the first time, it's found: ✦ %d" % gaps.FIRST_SPARKLES)
	gaps.check_landing(z[0], z[2], 0.9, false, false, false, null, null, s)
	check(game.sparkles == sparkles + gaps.FIRST_SPARKLES, "landing it again doesn't pay again")
	check(tricks.combo.size() == 2 and tricks.combo[1].points == 250, "...and in the same combo it's worth half, like a trick")
	# The combo is paid out once she rolls away
	var score: int = tricks.score
	for i in 40:
		tricks.update_ground(1.0 / 60.0)
	check(tricks.combo.is_empty() and tricks.score > score, "the gaps are paid out with the combo (%d)" % (tricks.score - score))
	# Not far enough, or from the wrong place: nothing
	tricks.lose()
	got = gaps.check_landing(z[0], z[0] + Vector3(1, 0, 0), 0.5, false, false, false, null, null, s)
	check(not "hollow_yard_gap" in got and tricks.combo.is_empty(), "a hop on the kicker isn't the gap")
	got = gaps.check_landing(z[2], z[0], 0.9, false, false, false, null, null, s)
	check(not "hollow_yard_gap" in got, "...nor landing on the kicker from the deck (it only goes one way)")
	var f: Array = gaps.zone("yard_funbox_hop")
	check("yard_funbox_hop" in gaps.check_landing(f[0], f[2], 0.7, false, false, false, null, null, s)
		and "yard_funbox_hop" in gaps.check_landing(f[2], f[0], 0.7, false, false, false, null, null, s),
		"over the funbox counts either way")
	var stairs: Array = gaps.zone("school_stair_set")
	check("school_stair_set" in gaps.check_landing(stairs[0] + Vector3.UP * 1.6, stairs[2], 0.7, false, false, false, null, null, s),
		"off the top of the school steps to the bottom: the School Stair Set")
	check(not "school_stair_set" in gaps.check_landing(stairs[2], stairs[0] + Vector3.UP * 1.6, 0.7, false, false, false, null, null, s),
		"...but not up them")

	# Gaps anywhere
	var here: Vector3 = p.global_position
	check("hang_time" in gaps.check_landing(here, here + Vector3(2, 0, 0), 2.2, false, false, false, null, null, s), "2 s in the air: Hang Time")
	check(not "hang_time" in gaps.check_landing(here, here, 2.4, true, false, false, null, null, s), "...but not straight up a quarter pipe")
	check("long_gap" in gaps.check_landing(here, here + Vector3(13, 0, 0), 1.0, false, false, false, null, null, s), "13 m in one jump: Long Gap")
	check("big_drop" in gaps.check_landing(here + Vector3.UP * 4.0, here, 1.0, false, false, false, null, null, s), "a 4 m drop: Big Drop")
	var rails: Array = current_scene.find_children("*", "GrindRail", true, false)
	check("rail_transfer" in gaps.check_landing(here, here + Vector3(3, 0, 0), 0.6, false, true, true, rails[0], rails[1], s),
		"rail to another rail: Rail Transfer")
	check(not "rail_transfer" in gaps.check_landing(here, here + Vector3(3, 0, 0), 0.6, false, true, true, rails[0], rails[0], s),
		"...not back onto the same rail")
	tricks.lose()

	# For real: ride off the yard's gap kicker, and off the Big Air Kicker, and see what's landed
	dialogue.flags.erase("gap_hollow_yard_gap")
	var landed := []
	gaps.landed_gap.connect(func(id: String, _pts: int) -> void: landed.append(id))
	var best_yard := await _launch(p, s, "Hollow Skate Yard/Gap Kicker", [9.0, 10.0, 11.0, 12.0], "hollow_yard_gap", landed)
	check(best_yard != "", "riding off the gap kicker for real lands the Hollow Yard Gap (%s)" % best_yard)
	var best_hill := await _launch(p, s, "Big Air Kicker", [13.0, 15.0, 17.0, 19.0], "lookout_launch", landed)
	check(best_hill != "", "riding off the Big Air Kicker fast lands the Lookout Launch (%s)" % best_hill)

	# Galaxity's park has its own
	game.riding = false
	change_scene_to_file(TOWN)
	await _frames(8)
	check(not gaps.zone("park_funbox_hop").is_empty() and gaps.zone("hollow_yard_gap").is_empty(), "in Galaxity, the Skate Park's Funbox Hop is placed")
	# The Skate page lists them
	root.get_node("PlayerMenu").open("skate")
	await _frames(3)
	var texts: Array = root.get_node("PlayerMenu").find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	check(texts.any(func(t: String) -> bool: return t.begins_with("Gaps found: ")), "the Skate page counts the gaps found")
	check(texts.any(func(t: String) -> bool: return t.contains("Hollow Yard Gap")) and texts.any(func(t: String) -> bool: return t.contains("???")),
		"...naming the found ones and hinting where the rest are")
	root.get_node("PlayerMenu").close()
	_finish()


func _launch(p: CharacterBody3D, s: Node, piece: String, speeds: Array, want: String, landed: Array) -> String:
	# Rolls at the kicker straight on at each speed until the gap's landed; returns the speed that did it ("" if none)
	var k: Node3D = gaps._piece(current_scene, piece)
	var fwd: Vector3 = k.global_basis.z.normalized()
	for v in speeds:
		landed.clear()
		s.tricks.lose()
		var start: Vector3 = k.global_position - fwd * 8.0
		start.y = maxf(k.global_position.y, EarthLand.height(start.x, start.z)) + 1.0     # (the Big Air Kicker is at the foot of a hill)
		p.global_position = start
		var yaw := atan2(fwd.x, fwd.z)
		s.set("_yaw", yaw)
		s.set("_shown_yaw", yaw)
		s.set("state", 0)
		p.visual.rotation.y = yaw
		await _physics(3)
		for i in 240:
			if i < 50:
				var h := Vector3(p.velocity.x, 0, p.velocity.z)
				if s.state == 0:
					p.velocity = fwd * float(v) + Vector3.UP * p.velocity.y
			await physics_frame
			if want in landed:
				return "%.0f m/s" % v
		print("  (at %.0f m/s: landed %s, state %d, last jump %s, zone %s)" % [v, str(landed), s.state, str(gaps.last_jump), str(gaps.zone(want))])
	return ""


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	for id in gaps.all_ids():
		dialogue.flags.erase("gap_" + id)
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

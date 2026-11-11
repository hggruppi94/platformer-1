extends SceneTree

# Checks Melody's groove and her stage, Rhythm Springs' reward (scripts/groove.gd, scripts/melody_stage.gd,
# Portals._melody_stage(), routines/melody.json "mended"): before Rhythm Springs is mended the move's a secret (not on
# the Controls list, D-pad right still picks gadgets, pressing it does nothing) and there's no stage; once it's mended
# Melody teaches it as the Off-Beat shrinks back into time; a groove spins the hero, sets enemies near them dancing
# for a while and lets them go after; grooving on the beat again and again builds a streak and a bigger ring, four in
# a row is a speed rush, off the beat it starts again, and a pause loses it; not on a ride or while someone's holding
# the controls; the stage stands by her portal on flat, clear ground off the Lake Loop; Melody's evening is a show on
# it; eight on the beat in a row on the stage during her show is an encore, once a visit; and it all saves.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_groove.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.groove_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.groove_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const WORLD := "res://scenes/portal_worlds/rhythm_springs.tscn"

var failures := 0
var game: Node
var portals: Node
var settings: Node
var clock: Node
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
	portals = root.get_node("Portals")
	settings = root.get_node("Settings")
	clock = root.get_node("Clock")
	dialogue = root.get_node("Dialogue")
	settings.tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	clock.set("pulls_home", false)
	clock.set_time(3, 10 * 60.0, true)
	root.get_node("Quests").state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	for w in ["shard_isle", "rootmind", "frozen_moment", "lanternmoor", "rhythm_springs"]:
		portals.quakes.append(w)
	for w in ["shard_isle", "rootmind", "frozen_moment", "lanternmoor"]:
		portals.cleared_worlds.append(w)

	await _check_locked()
	await _check_teaching()
	await _check_groove()
	await _check_stage()
	await _check_show()
	_check_saving()
	_finish()


func _player() -> CharacterBody3D:
	return current_scene.find_child("Player", true, false) as CharacterBody3D


func _on_next_beat(g: Node, off := 0.0) -> void:
	# Move the groove's beat clock on to the next beat (plus `off` seconds), and let it be pressed again
	g.clock_offset += g.BEAT - fposmod(g.now(), g.BEAT) + off
	g.cooldown = 0.0


func _check_locked() -> void:
	change_scene_to_file(TOWN)
	await _frames(10)
	await _physics(4)
	var p := _player()
	var g := p.get_node_or_null("Groove")
	check(g != null, "the player has a Groove node")
	check(settings.default_bindings().get("groove") == KEY_G and settings.default_pad_bindings().get("groove") == JOY_BUTTON_DPAD_RIGHT,
		"Groove is on G and D-pad right")
	check(not settings.action_shown("groove"), "Groove isn't on the Controls list before Rhythm Springs is mended")
	var wheel: Node = load("res://scripts/gadget_wheel.gd").new()
	check(wheel._secret_on(JOY_BUTTON_DPAD_RIGHT), "...so D-pad right still picks gadgets")
	check(not g.try_groove() and g.grooves == 0, "pressing it does nothing yet")
	check(current_scene.get_node_or_null("Portals/Melody's Stage") == null, "and there's no stage in the Void yet")
	portals.cleared_worlds.append("rhythm_springs")
	check(not wheel._secret_on(JOY_BUTTON_DPAD_RIGHT), "once it's mended D-pad right is Groove's")
	portals.cleared_worlds.erase("rhythm_springs")
	wheel.free()


func _check_teaching() -> void:
	change_scene_to_file(WORLD)
	await _frames(10)
	await _physics(4)
	var s := current_scene
	var lines: Array = s.teach_lines()
	check(lines.any(func(l: String) -> bool: return l.contains("{groove}")), "Melody's lesson says which button to press")
	s.mend()
	check(portals.is_cleared("rhythm_springs"), "mending Rhythm Springs...")
	check(settings.action_shown("groove"), "...puts Groove on the Controls list")
	await create_timer(s.TEACH_AFTER + 0.6).timeout
	check(dialogue.is_active(), "...and Melody teaches it a moment after")
	dialogue.end()
	await _frames(4)
	check(not dialogue.is_active(), "(the lesson can be closed)")
	var mended_lines: Array = s.melody_lines()
	check(mended_lines.size() > 0, "she has lines once it's mended")


func _check_groove() -> void:
	clock.set_time(3, 10 * 60.0, true)
	change_scene_to_file(TOWN)
	await _frames(10)
	await _physics(4)
	var p := _player()
	var g := p.get_node("Groove")
	# Out on open ground by the stage
	var spot: Vector3 = root.get_node("Remnants").ground_at(Vector2(-24.0, 46.0))
	p.global_position = spot + Vector3(0, 1.0, 0)
	p.velocity = Vector3.ZERO
	await _physics(20)
	# A Gloop close by
	var gloop: Node3D = null
	for e in get_nodes_in_group("enemies"):
		if e is CharacterBody3D and str(e.name).begins_with("Gloop") and not e.get("defeated"):
			gloop = e
			break
	check(gloop != null, "(there's a Gloop to dance)")
	if gloop:
		gloop.global_position = p.global_position + Vector3(3.0, 0.5, 0)
	await _physics(2)
	_on_next_beat(g)
	check(g.on_beat(), "(the beat clock is on a beat)")
	var r0: float = (p.model as Node3D).rotation.y
	check(g.try_groove() and g.grooves == 1, "grooving works once it's mended")
	check(g.streak == 1 and is_equal_approx(g.last_ring, g.ring_for(1)), "on the beat: a streak of 1 and a ring of %.1f m" % g.last_ring)
	check(g.card_shown(), "the beat card shows")
	if gloop:
		check(g.is_dancing(gloop) and not gloop.is_physics_processing(), "a Gloop close by stops and dances")
	await create_timer(0.2).timeout
	check(absf((p.model as Node3D).rotation.y - r0) > 0.3, "the hero spins")
	await create_timer(0.4).timeout
	check(is_equal_approx((p.model as Node3D).rotation.y, r0), "...and ends facing the same way")
	for k in 2:
		_on_next_beat(g)
		g.try_groove()
	_on_next_beat(g)
	g.try_groove()
	check(g.streak == 4, "four on the beat in a row: a streak of 4 (%d)" % g.streak)
	check(is_equal_approx(g.last_ring, g.RING + g.RING_GROWS * 4), "...a much bigger ring (%.1f m)" % g.last_ring)
	check(not p.boosting(), "...standing still, you stay where you are")
	p.velocity = Vector3(4.0, 0, 0)
	_on_next_beat(g)
	g.try_groove()
	check(p.boosting(), "...on the move, the music carries the hero along (a speed rush)")
	p.velocity = Vector3.ZERO
	_on_next_beat(g)
	g.try_groove()
	check(g.streak == 6 and is_equal_approx(g.last_ring, g.ring_for(4)), "the ring doesn't grow past four")
	_on_next_beat(g, 0.4)
	check(not g.on_beat(), "(half a beat later is off the beat)")
	g.try_groove()
	check(g.streak == 0 and is_equal_approx(g.last_ring, g.RING), "off the beat: the streak starts again, small ring")
	_on_next_beat(g)
	g.try_groove()
	g.clock_offset += g.BEAT * 3.0
	await _frames(2)
	check(g.streak == 0, "a long pause and the groove's gone")
	# Cooldown
	_on_next_beat(g)
	g.try_groove()
	check(not g.try_groove(), "not twice at once")
	# Not riding, not while held
	g.cooldown = 0.0
	game.hold_controls(&"groove_test", true, p)
	check(not g.can_groove(), "not while something holds the controls")
	game.hold_controls(&"groove_test", false, p)
	game.riding = true
	check(not g.can_groove(), "not on a ride")
	game.riding = false
	check(g.can_groove(), "fine again after")
	# The dancing Gloop is let go after a while
	if gloop:
		check(g.is_dancing(gloop), "the Gloop's still dancing")
		g.clock_offset += g.DANCE_TIME + 0.5
		await _frames(3)
		check(not g.is_dancing(gloop) and gloop.is_physics_processing(), "...and after a while it's let go")
		gloop.global_position += Vector3(0, 0, 200)        # (off it goes, so it doesn't bump into the stage checks)


func _check_stage() -> void:
	var stage := current_scene.get_node_or_null("Portals/Melody's Stage") as Node3D
	check(stage != null, "Melody's Stage stands in the Void once Rhythm Springs is mended")
	if stage == null:
		return
	var rem := root.get_node("Remnants")
	var at := Vector2(stage.global_position.x, stage.global_position.z)
	# (the ground round it: the middle is the stage's own floor now)
	var ground: Vector3 = rem.ground_at(at + Vector2(stage.RADIUS + 1.8, 0).rotated(0.4))
	check(absf(stage.global_position.y - ground.y) < 0.3, "...on the ground")
	var portal: Vector2 = portals.world("rhythm_springs").at
	check(at.distance_to(portal) < 14.0 and at.distance_to(portal) > stage.RADIUS + 4.0, "...beside her portal, not on it (%.1f m)" % at.distance_to(portal))
	var worst := 0.0
	for k in 16:
		var a := k * TAU / 16.0
		worst = maxf(worst, absf(rem.ground_at(at + Vector2(cos(a), sin(a)) * (stage.RADIUS + 1.8)).y - ground.y))
	check(worst < 0.4, "...on flat ground (worst step %.2f)" % worst)
	var space := (current_scene as Node3D).get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = stage.RADIUS + 0.5
	q.shape = sphere
	q.transform = Transform3D(Basis(), stage.global_position + Vector3(0, stage.RADIUS + 1.2, 0))
	var others := space.intersect_shape(q, 16).filter(func(h: Dictionary) -> bool:
		var c: Node = h.collider
		return (not stage.is_ancestor_of(c) and not c.is_in_group("player") and not c.is_in_group("enemies")
			and not (c.get_parent() != null and c.get_parent().name == "Melody")))
	check(others.is_empty(), "nothing else stands on the stage (%s)" % str(others.map(func(h): return str(h.collider.name))))
	var tracks: Dictionary = root.get_node("Races").TRACKS
	for id in tracks:                                           # (the races have their own circuits now, so only the
		if str(tracks[id].get("scene", "")) != "res://scenes/town/town.tscn" or tracks[id].get("sky", false):   # sky)
			continue
		var d := _off_line(at, tracks[id].points, true)
		check(d > 11.0, "...well off the %s's racing line (%.1f m)" % [tracks[id].get("name", id), d])
	var gate: Vector2 = root.get_node("Races").HUBS.void.at
	check(at.distance_to(gate) > 14.0, "...and well away from Zippy's race gate (%.1f m)" % at.distance_to(gate))
	# ...and off the paths people walk along (routines/places.json), apart from the way up to it
	var places: Dictionary = (load("res://routines/places.json") as JSON).data
	var pts: Dictionary = places.points
	var closest := INF
	for link in places.links:
		if "melody_stage" in link or "stage_front" in link:
			continue
		var a := Vector2(pts[link[0]][0], pts[link[0]][1])
		var b := Vector2(pts[link[1]][0], pts[link[1]][1])
		closest = minf(closest, _off_line(at, [a, b], false))
	check(closest > stage.RADIUS + 3.0, "...and clear of everyone's walks round town (%.1f m)" % closest)
	await _frames(2)
	var left := 0
	for holder_name in ["Trees", "Foliage"]:
		var holder := current_scene.find_child(holder_name, true, false)
		if holder == null:
			continue
		for n in holder.get_children():
			if n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh:
				var mm := (n as MultiMeshInstance3D).multimesh
				for i in mm.instance_count:
					var t := mm.get_instance_transform(i)
					if stage.in_the_way((n as Node3D).global_transform * t.origin) and t.basis.get_scale().x > 0.001:
						left += 1
	check(left == 0, "no plants grow on the stage or in front of it (%d moved out of the way)" % stage.cleared_plants)
	var front := Vector2(sin(stage.rotation.y), cos(stage.rotation.y))
	check(front.dot(-at.normalized()) > 0.8, "...facing the lake")
	# Standing on it
	var p := _player()
	p.global_position = stage.global_position + Vector3(0, 1.2, 0)
	p.velocity = Vector3.ZERO
	var waited := 0
	while p.boosting() and waited < 200:                 # (the rush from before wears off)
		await physics_frame
		waited += 1
	p.global_position = stage.global_position + Vector3(0, 1.2, 0)
	p.velocity = Vector3.ZERO
	await _physics(30)
	check(p.is_on_floor() and p.global_position.y > stage.global_position.y + stage.TOP - 0.1, "you can stand on the stage")
	check(stage.on_stage(p), "...and it knows you're on it (%s)" % stage.to_local(p.global_position))
	var light: StandardMaterial3D = stage._lights[0][1]
	var g := p.get_node("Groove")
	stage.flash = 0.0
	_on_next_beat(g)
	g.try_groove()
	await _frames(3)
	check(stage.flash > 0.5 and light.emission_energy_multiplier > 2.0, "grooving on the stage flashes its footlights")


func _check_show() -> void:
	var stage := current_scene.get_node("Portals/Melody's Stage") as Node3D
	var routine: Node = null
	for r in get_nodes_in_group("routines"):
		if str(r.get("character_id")) == "melody":
			routine = r
	check(routine != null, "(Melody's in the Void)")
	if routine == null:
		return
	clock.set_time(3, 19 * 60.0, true)
	await _physics(10)
	check(routine.activity() == "show" and routine.place() == "melody_stage", "at 7 PM Melody's doing her show on her stage (%s, %s)" % [routine.activity(), routine.place()])
	var mel := routine.get_parent() as Node3D
	check(Vector2(mel.global_position.x - stage.global_position.x, mel.global_position.z - stage.global_position.z).length() < 1.0
		and mel.global_position.y > stage.global_position.y + stage.TOP - 0.2, "...standing up on it")
	check(stage.show_on(), "the stage knows the show's on")
	dialogue.talks["melody"] = 3
	var said := " ".join(dialogue.pick_conversation("melody"))
	check(said.contains("stage"), "talking to her then gets her show lines")
	# The dance-off
	var p := _player()
	p.global_position = stage.global_position + stage.global_basis.z * 1.8 + Vector3(0, stage.TOP + 0.6, 0)
	p.velocity = Vector3.ZERO
	await _physics(20)
	check(stage.on_stage(p), "(the player's up on the stage)")
	var g := p.get_node("Groove")
	var before: int = game.sparkles
	g.clock_offset += g.BEAT * 4.0                      # (a fresh start: the last groove was a while ago)
	await _frames(2)
	for k in stage.DANCE_OFF - 1:
		_on_next_beat(g)
		g.try_groove()
	check(game.sparkles == before and stage.encores == 0, "seven in a row isn't an encore yet (%d, %d)" % [game.sparkles - before, stage.encores])
	_on_next_beat(g)
	g.try_groove()
	check(stage.encores == 1 and game.sparkles == before + stage.PRIZE, "eight on the beat in a row: an encore! (+%d sparkles)" % (game.sparkles - before))
	check(portals.stage_prize_day == root.get_node("Requests").visit_day(), "...remembered for this visit")
	for k in stage.DANCE_OFF + 1:
		_on_next_beat(g)
		g.try_groove()
	check(stage.encores == 1 and game.sparkles == before + stage.PRIZE, "only one encore a visit")
	# Not in the morning
	clock.set_time(4, 10 * 60.0, true)
	await _physics(10)
	check(not stage.show_on(), "in the morning there's no show")
	var b2: int = game.sparkles
	p.global_position = stage.global_position + Vector3(0, stage.TOP + 0.6, 0)
	await _physics(10)
	for k in stage.DANCE_OFF:
		_on_next_beat(g)
		g.try_groove()
	check(game.sparkles == b2, "...and no encore without Melody")


func _check_saving() -> void:
	var data: Dictionary = portals.save_data()
	check(int(data.get("stage_prize_day", -9)) == portals.stage_prize_day, "the encore's visit is saved")
	var day: int = portals.stage_prize_day
	portals.load_data(data)
	check(portals.stage_prize_day == day and portals.is_cleared("rhythm_springs"), "...and loads back")
	var old := data.duplicate()
	old.erase("stage_prize_day")
	portals.load_data(old)
	check(portals.stage_prize_day == -1, "an older save has no encore yet")


func _off_line(at: Vector2, line: Array, loop: bool) -> float:
	var nearest := INF
	var n := line.size() if loop else line.size() - 1
	for i in n:
		var a: Vector2 = line[i]
		var b: Vector2 = line[(i + 1) % line.size()]
		var t := clampf((at - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		nearest = minf(nearest, at.distance_to(a.lerp(b, t)))
	return nearest


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	print("RESULT " + ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	game.hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	else:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	quit(1 if failures else 0)

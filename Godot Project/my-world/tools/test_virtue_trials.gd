extends SceneTree

# Checks the seven virtue trials on the Skyreach Trail (scripts/virtue_trial.gd, the gates and Waystone portals in
# scripts/skyreach_trail.gd): every Waystone has a gate of light after it that you can't walk through; hugging the
# Waystone takes you into its trial; each trial can really be done (Humility's wind sends a proud jump back, Patience's
# stones only come when you're still, the lamb follows you home, a sixth pear puts them all back, Charity takes every
# sparkle and gives twice back, Diligence's lamps catch a fall, Purity's mists send you back to a lily); the altar does
# nothing until the trial's done; finishing puts you back by the Waystone with its gate opening and pays once; leaving
# early gives back what Charity took; saving in a trial saves you at the Waystone, sparkles and all; and all seven give
# the Laurel of Virtues.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_virtue_trials.gd
#
# Your own save and settings are put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.virtue_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.virtue_backup.cfg"
const SKYREACH := "res://scenes/bosses/skyreach_trail.tscn"
const TRIAL_SCENE := "res://scenes/bosses/virtue_trial.tscn"
var VIRTUE: GDScript

var failures := 0
var game: Node
var bosses: Node
var dialogue: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(600.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	bosses = root.get_node("Bosses")
	dialogue = root.get_node("Dialogue")
	VIRTUE = load("res://scripts/virtue_trial.gd")
	var settings := root.get_node("Settings")
	settings.use_layout("classic")
	settings.tips = false
	game._reset_state()
	game.needs_creator = false
	game._resume = {}
	game.pending_message = ""
	game.riding = false
	game.hold_saves = true
	root.get_node("Clock").set("pulls_home", false)
	for v in VIRTUE.VIRTUES:
		dialogue.flags.erase("virtue_" + str(v.id))
	dialogue.flags.erase("virtue_all")
	for m in ["lair_resume", "virtue_trial", "virtue_back", "virtue_opened"]:
		if bosses.has_meta(m):
			bosses.remove_meta(m)

	# --- The trail: seven gates, all shut ---
	change_scene_to_file(SKYREACH)
	await _frames(8)
	await _physics(4)
	var trail := current_scene as Node3D
	var p := _player()
	for e in get_nodes_in_group("enemies"):
		(e as Node).process_mode = Node.PROCESS_MODE_DISABLED
	var shut := 0
	for k in 7:
		if trail.call("gate_closed", k):
			shut += 1
	check(shut == 7, "seven gates of light stand across the trail, all shut (%d)" % shut)
	var stones: Array = trail.get("stones")
	var rings := 0
	for k in 7:
		if (stones[k] as Node3D).has_node("Portal Ring") and (stones[k] as Node3D).has_node("Portal Light"):
			rings += 1
	check(rings == 7, "each of the seven Waystones glows in its virtue's light (%d)" % rings)

	# Walking into the first gate: it holds you back
	var T: GDScript = trail.get_script()
	var ga := (float(T.STONES[0]) + float(T.GATE_AFTER)) * PI
	var before: Vector3 = T.trail_point(ga - 0.06) + Vector3(0, 1.0, 0)
	var beyond: Vector3 = T.trail_point(ga + 0.08)
	p.global_position = before
	p.velocity = Vector3.ZERO
	await _physics(4)
	for i in 150:
		_steer(p, (beyond - p.global_position) * Vector3(1, 0, 1))
		await physics_frame
	_release()
	var gate_at: Vector3 = T.trail_point(ga)
	var past := (p.global_position - gate_at).dot(beyond - gate_at) > 0.3
	check(not past, "the first gate won't let you walk on up the trail")

	# Hugging the first Waystone takes you into the Trial of Humility
	var s0 := stones[0] as Node3D
	var s0_at := s0.global_position
	p.global_position = s0_at + Vector3(0.9, 0.9, 0)
	p.velocity = Vector3.ZERO
	var t := await _wait_scene(TRIAL_SCENE, 300)
	check(t, "hugging the first Waystone takes you into its trial")
	if not t:
		_finish()
		return
	await _frames(4)
	await _physics(4)
	var lair := current_scene as Node3D
	check(str(lair.get("id")) == "humility", "...the Trial of Humility")
	var sp: Dictionary = VIRTUE.save_place()
	check(str(sp.get("scene", "")) == SKYREACH, "saving in a trial saves you back on the trail")
	var spos: Array = sp.get("position", [0, 0, 0])
	check(Vector3(spos[0], spos[1], spos[2]).distance_to(s0_at) < 5.0, "...beside its Waystone")

	# --- Humility ---
	p = _player()
	var start_spark: int = game.sparkles
	var start_rem: int = root.get_node("Remnants").count
	p.global_position = Vector3(0, 3.0, 20.0)
	p.velocity = Vector3.ZERO
	await _physics(3)
	check(p.global_position.z < 11.0, "Humility: a proud leap under the arches is blown back to their start")
	var ok := await _walk(p, [Vector3(0, 0, 12), Vector3(0, 0, 30), Vector3(0, 0, 50)], 1400)
	check(ok, "Humility: you can walk the low path under all eight arches to the altar")
	await _back(k_of("humility"))
	check(game.sparkles == start_spark + VIRTUE.REWARD, "...8 sparkles the first time (%d)" % (game.sparkles - start_spark))
	check(root.get_node("Remnants").count == start_rem + 1, "...and a Remnant")

	# --- Patience ---
	await _enter("patience")
	lair = current_scene as Node3D
	p = _player()
	var first_stone := lair.get_node("Waiting Stone 1 Body") as StaticBody3D
	check((first_stone.get_child(0) as CollisionShape3D).disabled, "Patience: the stones aren't there to begin with")
	# Running about near it doesn't bring it
	p.global_position = Vector3(0, 0.9, 9.0)
	for i in 120:
		_steer(p, Vector3(1, 0, 0) if (i / 30) % 2 == 0 else Vector3(-1, 0, 0))
		await physics_frame
	_release()
	check(int(lair.get("revealed")) == 0, "...running about doesn't bring them")
	var stood := true
	for k in 7:
		var on := Vector3(0, 0.9, 9.6) if k == 0 else Vector3(0, 0.9, 14.0 + (k - 1) * 4.0)
		p.global_position = on
		p.velocity = Vector3.ZERO
		await _physics(int(2.6 * 60))
		if int(lair.get("revealed")) != k + 1:
			stood = false
		await _physics(2)
		if k > 0 and absf(p.global_position.y - 0.8) > 0.25:
			stood = false
	check(stood, "...stand still and each comes out of the clouds in turn, solid to stand on")
	ok = await _walk(p, [Vector3(0, 0, 44)], 500)
	check(ok, "...and on to the altar")
	await _back(k_of("patience"))

	# --- Kindness ---
	await _enter("kindness")
	lair = current_scene as Node3D
	p = _player()
	var alt: Vector3 = lair.get("altar_at")
	p.global_position = alt + Vector3(0, 0.9, 0)
	await _physics(6)
	check(not bool(lair.get("done")), "Kindness: the altar waits until the lamb is home")
	p.global_position = Vector3(0, 0.9, 8)
	await _physics(3)
	ok = await _walk(p, [Vector3(0, 0, 24), Vector3(-15, 0, 24), Vector3(-18, 0, 25)], 1200)
	check(ok and bool(lair.get("lamb_following")), "...walk out to the lost lamb and it follows you")
	ok = await _walk(p, [Vector3(-8, 0, 24), Vector3(0, 0, 24), Vector3(12, 0, 24), Vector3(15, 0, 23)], 1600)
	await _physics(30)
	check(lair.call("lamb_home"), "...lead it over the bridges to its mother")
	ok = await _walk(p, [alt], 400)
	check(ok, "...then the altar takes you")
	await _back(k_of("kindness"))

	# --- Temperance ---
	await _enter("temperance")
	lair = current_scene as Node3D
	p = _player()
	var pears: Array = lair.get("pears")
	for i in 6:
		var g := pears[i] as Node3D
		p.global_position = g.global_position + Vector3(0, 0.9, 0)
		await _physics(3)
	check(int(lair.get("carried")) == 0, "Temperance: take a sixth pear and they all go back")
	var all_back := true
	for g in pears:
		if not (g as Node3D).visible:
			all_back = false
	check(all_back, "...every one back on its stand")
	for i in 5:
		var g := pears[i + 10] as Node3D
		p.global_position = g.global_position + Vector3(0, 0.9, 0)
		await _physics(3)
	check(int(lair.get("carried")) == 5, "...take just five")
	p.global_position = Vector3(0, 0.9, 30)
	ok = await _walk(p, [lair.get("altar_at")], 400)
	check(ok, "...and the scales take them")
	await _back(k_of("temperance"))

	# --- Charity: leaving early gives back exactly what you gave ---
	game.sparkles = 37
	await _enter("charity")
	lair = current_scene as Node3D
	p = _player()
	for i in 120:
		_steer(p, Vector3(0, 0, 1))
		await physics_frame
	_release()
	check(p.global_position.z < 10.5, "Charity: a wall of light holds you until you've given")
	(lair.get_node("Giving Bowl/Bowl Spot").get("act") as Callable).call()
	await _physics(3)
	check(game.sparkles == 0 and VIRTUE.held() == 37, "...the bowl takes every sparkle (37 held)")
	check(int(VIRTUE.save_place().is_empty()) == 0, "...and a save made now is back on the trail")
	(lair.get_node("Way Out/Home Spot").get("act") as Callable).call()
	var back_ok := await _wait_scene(SKYREACH, 300)
	await _frames(4)
	check(back_ok and game.sparkles == 37, "...leave early and you get all 37 back")
	trail = current_scene as Node3D
	check(trail.call("gate_closed", k_of("charity")), "...and its gate stays shut")

	# --- Charity, done properly: twice back ---
	await _enter("charity")
	lair = current_scene as Node3D
	p = _player()
	(lair.get_node("Giving Bowl/Bowl Spot").get("act") as Callable).call()
	await _physics(3)
	ok = await _walk(p, [Vector3(1.8, 0, 6), Vector3(1.8, 0, 7.5), Vector3(0, 0, 10.6), Vector3(0, 0, 16)], 600)
	check(ok, "...the way opens once you've given")
	for f in lair.get("feathers"):
		var fp: Vector3 = (f as Node3D).global_position
		p.global_position = Vector3(fp.x, 0.9, fp.z)
		await _physics(3)
	check(int(lair.get("feathers_held")) == 6, "...six feathers gathered")
	for c in lair.get("cherubs"):
		var cp: Vector3 = (c as Node3D).global_position
		p.global_position = Vector3(cp.x, 0.9, cp.z)
		await _physics(3)
	check(int(lair.get("happy")) == 6, "...six happy cherubs")
	p.global_position = Vector3(0, 0.9, 23)
	var spark_before: int = game.sparkles
	ok = await _walk(p, [Vector3(0, 0, 28), lair.get("altar_at")], 600)
	check(ok, "...over the golden bridge to the altar")
	await _physics(10)
	check(game.sparkles == spark_before + 74 + VIRTUE.REWARD, "...and your 37 come back twice over: 74 (and 8)")
	await _back(k_of("charity"))

	# --- Diligence ---
	await _enter("diligence")
	lair = current_scene as Node3D
	p = _player()
	var climbed := true
	for k in 30:
		p.global_position = VIRTUE.step_at(k) + Vector3(0, 0.9, 0)
		p.velocity = Vector3.ZERO
		await _physics(8)
		if absf(p.global_position.y - (VIRTUE.step_at(k).y + 0.8)) > 0.3:
			climbed = false
		if k == 20:
			check(int(lair.get("lamp_at")) == 20, "Diligence: the lamp on step 21 lights as you pass")
			p.global_position = Vector3(0, 0.9, 12)
			await _physics(4)
			check(p.global_position.y > VIRTUE.step_at(20).y, "...slip all the way down and you float back up to it")
	check(climbed, "...every one of the thirty steps holds you up")
	ok = await _walk(p, [lair.get("altar_at")], 400)
	check(ok, "...and at the top, the altar")
	await _back(k_of("diligence"))

	# --- Purity ---
	await _enter("purity")
	lair = current_scene as Node3D
	p = _player()
	var mist := (lair.get("mists") as Array)[0] as Node3D
	p.global_position = Vector3(mist.position.x, 0.9, mist.position.z)
	await _physics(2)
	check(p.global_position.z < 9.0, "Purity: touch a dark mist and you're sent back")
	var safe := true
	for z in [16.25, 22.75, 29.25, 35.75, 42.0, 46.0, 51.0]:
		p.global_position = Vector3(0, 0.9, z)
		p.velocity = Vector3.ZERO
		await _physics(3)
		if absf(p.global_position.z - z) > 0.5:
			safe = false
	check(safe, "...between the mists you're safe")
	check(int(lair.get("lily_at")) == 2, "...and the lilies are where you'd start again")
	ok = await _walk(p, [lair.get("altar_at")], 400)
	check(ok, "...and the altar")
	await _back(k_of("purity"))

	# --- All seven ---
	check(VIRTUE.all_done() and dialogue.flags.has("virtue_all"), "all seven trials done")
	check(game.has_item("shop:virtue_laurel"), "...and the Laurel of Virtues is yours")
	trail = current_scene as Node3D
	var open := 0
	for k in 7:
		if not trail.call("gate_closed", k):
			open += 1
	check(open == 7, "every gate on the trail is open now (%d)" % open)
	# Doing one again pays nothing new
	var before_again: int = game.sparkles
	await _enter("humility")
	lair = current_scene as Node3D
	p = _player()
	ok = await _walk(p, [Vector3(0, 0, 12), Vector3(0, 0, 50)], 1400)
	await _physics(10)
	check(game.sparkles == before_again, "doing a trial again pays nothing more")
	await _wait_scene(SKYREACH, 400)
	_finish()


func k_of(vid: String) -> int:
	for k in VIRTUE.VIRTUES.size():
		if str(VIRTUE.VIRTUES[k].id) == vid:
			return k
	return 0


func _enter(vid: String) -> void:
	# From the trail, as its Waystone does it
	var trail := current_scene
	if trail.scene_file_path != SKYREACH:
		print("(not on the trail)")
	trail.call("enter_trial", k_of(vid))
	var ok := await _wait_scene(TRIAL_SCENE, 300)
	await _frames(4)
	await _physics(4)
	check(ok and str(current_scene.get("id")) == vid, "into the Trial of %s" % str(VIRTUE.virtue_of(vid).name))


func _back(k: int) -> void:
	# Finished: back on the trail by the Waystone, its gate opening
	var vid := str(VIRTUE.VIRTUES[k].id)
	check(dialogue.flags.has("virtue_" + vid), "the Trial of %s is done" % str(VIRTUE.VIRTUES[k].name))
	var ok := await _wait_scene(SKYREACH, 600)
	await _frames(4)
	await _physics(6)
	var trail := current_scene as Node3D
	var p := _player()
	var stone := (trail.get("stones") as Array)[k] as Node3D
	check(ok and p.global_position.distance_to(stone.global_position) < 5.0, "...back on the trail beside its Waystone")
	check(not trail.call("gate_closed", k), "...and its gate of light opens")
	await _physics(30)
	check(trail.is_inside_tree() and current_scene == trail, "...and you stay on the trail (no going straight back in)")


func _player() -> CharacterBody3D:
	return current_scene.find_child("Player", true, false) as CharacterBody3D


func _wait_scene(path: String, frames: int) -> bool:
	for i in frames:
		if current_scene and current_scene.scene_file_path == path and _player() != null:
			return true
		await physics_frame
	return false


func _walk(p: CharacterBody3D, points: Array, frames: int) -> bool:
	# Really walks through each point in turn (true if it got to the last one, or the trial ended on the way)
	var lair := current_scene
	var i := 0
	for f in frames:
		if current_scene != lair or bool(lair.get("done")):
			_release()
			return true
		var want: Vector3 = points[i]
		var to := (want - p.global_position) * Vector3(1, 0, 1)
		if to.length() < 0.8:
			i += 1
			if i >= points.size():
				_release()
				return true
			continue
		_steer(p, to)
		await physics_frame
	_release()
	return false


func _steer(p: CharacterBody3D, want: Vector3) -> void:
	if want.length() < 0.01:
		_release()
		return
	want = want.normalized()
	var b: Basis = p.get_node("SpringArm3D").global_transform.basis
	var fwd := Vector3(-b.z.x, 0, -b.z.z).normalized()
	var rgt := Vector3(b.x.x, 0, b.x.z).normalized()
	var ix := rgt.dot(want)
	var iy := -fwd.dot(want)
	_release()
	if ix > 0:
		Input.action_press("move_right", ix)
	else:
		Input.action_press("move_left", -ix)
	if iy > 0:
		Input.action_press("move_back", iy)
	else:
		Input.action_press("move_forward", -iy)


func _release() -> void:
	for a in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(a)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	_release()
	for v in ["virtue_trial", "virtue_back", "virtue_opened", "lair_resume"]:
		if bosses and bosses.has_meta(v):
			bosses.remove_meta(v)
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

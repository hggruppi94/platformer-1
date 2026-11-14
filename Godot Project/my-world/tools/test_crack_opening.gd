extends SceneTree

# Checks the cutscene for each crack that opens (scripts/crack_opening.gd; Hayden, 14 Nov 2026: "We need to make it
# more obvious when a crack opens up, with a cutscene for each one"): every portal world's quake has its shots (the
# player, the spot splitting open, a look down it, the world's name), none of them names a boss or anything still to
# come; a quake in the Void plays it with the controls held, the crack only splits open once the camera's over there,
# a pillar of light goes up and the preview wakes at the bottom, and when it's over the crack's open, the voice speaks
# and it saves; skipping it still leaves the crack open; a quake waits for a quiet moment (not in a talk); and the
# first time the crack by the old oak opens with you on Earth, it plays once, holding the crack shut till the camera
# gets there.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_crack_opening.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.crack_opening_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.crack_opening_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"
# Nothing a crack's cutscene says may name these (they're met later: Hayden's no-spoilers rule)
const SPOILERS := ["Gloop", "Thornknot", "Snatcher", "Stormram", "Riptide", "Glitch", "Chaos", "Agent", "Hush",
	"boss", "Boss", "Dash and Rex's", "experiment"]

var failures := 0
var game: Node
var portals: Node
var dialogue: Node
var quests: Node
var clock: Node
var cut: Node


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
	dialogue = root.get_node("Dialogue")
	quests = root.get_node("Quests")
	clock = root.get_node("Clock")
	cut = portals.opening_cut
	root.get_node("Settings").tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	clock.set("pulls_home", false)
	clock.set_time(3, 9 * 60.0, true)
	check(cut != null and cut.headless(), "the crack cutscene is there (and skipped in headless runs by default)")
	cut.force = true

	change_scene_to_file(TOWN)
	await _frames(10)
	await _physics(4)
	_check_shots()
	await _check_quake()
	await _check_skip()
	await _check_waits()
	await _check_earth()
	_finish()


func _check_shots() -> void:
	var worlds := 0
	for w in portals.WORLDS:
		if not portals.has_portal(str(w.id)) or not portals.is_built(str(w.id)):
			continue
		worlds += 1
		var shots: Array = cut.quake_shots(str(w.id))
		check(shots.size() == 4, "%s's quake has its four shots" % w.name)
		if shots.size() < 4:
			continue
		check(str(shots[0].title) != "" and float(shots[0].get("shake", 0.0)) > 0.0, "...it starts where you are, shaking")
		check(shots[1].has("start") and shots[1].has("call"), "...cuts over to its spot, where it splits open on cue")
		check(str(shots[3].title) == str(w.name), "...and ends on the world's name")
		check(cut.WORLDS.has(str(w.id)), "...with its own look down the crack")
		var words := ""
		for s in shots:
			words += str(s.get("title", "")) + " " + str(s.get("caption", "")) + " "
		var bad: Array = SPOILERS.filter(func(x: String) -> bool: return words.contains(x))
		check(bad.is_empty(), "...and gives nothing away (%s)" % ", ".join(bad))
	check(worlds >= 8, "every portal world's crack has a cutscene (%d)" % worlds)


func _check_quake() -> void:
	quests.state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	check(portals.next_due() == "shard_isle", "Shard Isle's quake is due")
	var quaked := [""]
	portals.quaked.connect(func(id: String) -> void: quaked[0] = id, CONNECT_ONE_SHOT)
	for i in 120:
		if cut.playing():
			break
		await create_timer(0.1).timeout
	check(cut.playing() and cut.showing == "shard_isle", "the quake plays Shard Isle's cutscene")
	var pl := get_first_node_in_group("player")
	check(pl != null and (pl.get("_input_locks") as Dictionary).has(&"place_intro"), "...with the controls held")
	check(not get_nodes_in_group("cutscene_playing").is_empty(), "...as a cutscene (the HUD and minimap step away)")
	check(portals.crack("shard_isle") == null, "...the crack isn't there till the camera's over at its spot")
	await create_timer(2.8).timeout
	var g: Node3D = portals.crack("shard_isle")
	check(g != null, "...then the ground splits open there")
	check(g != null and float(g.get_meta("open", 0.0)) < 0.99, "...unzipping as we watch")
	check(current_scene.find_child("Crack Pillar", true, false) != null, "...with a pillar of its light shooting up")
	check(quaked[0] == "", "...and the quake isn't over yet")
	await create_timer(3.8).timeout
	check(g != null and g.get_node_or_null("Preview") != null, "looking down it, the world shows at the bottom")
	for i in 150:
		if not cut.playing():
			break
		await create_timer(0.1).timeout
	await _frames(3)
	check(not cut.playing() and get_nodes_in_group("cutscene_playing").is_empty(), "the cutscene ends")
	check(quaked[0] == "shard_isle" and not portals._quaking, "...and the quake's over")
	check(g != null and float(g.get_meta("open", 0.0)) > 0.99 and (g.get_node("Fall") as Area3D).monitoring, "...the crack is open to jump in")
	check(root.get_node("DivineMind").said.any(func(l: String) -> bool: return l.contains("crack")), "...and the voice in your mind speaks")
	check(g != null and g.get_node_or_null("Preview") == null, "...and the preview sleeps again, far from you")


func _check_skip() -> void:
	var quaked := [""]
	portals.quaked.connect(func(id: String) -> void: quaked[0] = id, CONNECT_ONE_SHOT)
	portals.quake("rootmind")
	await _frames(5)
	check(cut.playing() and cut.showing == "rootmind", "the Rootmind's quake plays its cutscene")
	cut.cut.stop()                                    # (as pressing Jump does)
	await _frames(5)
	var g: Node3D = portals.crack("rootmind")
	check(g != null and float(g.get_meta("open", 0.0)) > 0.99, "skipped before it split, the crack's open all the same")
	check(quaked[0] == "rootmind" and not portals._quaking, "...and the quake's over")


func _check_waits() -> void:
	# A quake waits for a quiet moment
	check(cut.can_play(), "nothing's on: a cutscene could play")
	var talker := GDScript.new()
	talker.source_code = "extends Node3D\nfunc begin_talk() -> void:\n\tpass\nfunc end_talk() -> void:\n\tpass\n"
	talker.reload()
	var spot: Node3D = talker.new()
	current_scene.add_child(spot)
	dialogue.say(spot, "Someone", ["Hello!", "Still talking."], "crack_opening_test")
	await _frames(2)
	check(not cut.can_play() and not portals._quiet(), "in a talk, a quake waits")
	dialogue.end()
	spot.queue_free()
	await _frames(4)


func _check_earth() -> void:
	dialogue.flags["fn_fell"] = true
	dialogue.flags["oak_woken"] = true
	dialogue.flags["fn_arrived"] = true
	clock.set_earth_time(22 * 60.0, true)
	change_scene_to_file(EARTH)
	await _frames(10)
	await _physics(4)
	check(current_scene.scene_file_path == EARTH, "on Earth")
	check(cut.earth_due(), "the oak's crack hasn't had its cutscene yet")
	clock.set_earth_time(0.2, true)
	for i in 300:
		if cut.playing():
			break
		await process_frame
	check(cut.playing() and cut.showing == "earth", "at midnight the crack by the old oak plays its cutscene")
	check(dialogue.flags.has(cut.EARTH_FLAG) and not cut.earth_due(), "...once only")
	var crack: Node3D = current_scene.get("crack")
	await create_timer(1.2).timeout
	check(crack != null and float(crack.get_meta("open", 1.0)) < 0.01, "...the crack stays shut till the camera gets there")
	await create_timer(2.6).timeout
	check(crack != null and float(crack.get_meta("open", 0.0)) > 0.05, "...then it splits open")
	cut.cut.stop()
	await create_timer(3.0).timeout
	check(not cut.playing() and crack != null and float(crack.get_meta("open", 0.0)) > 0.99, "after it, the crack's wide open")
	clock.set_earth_time(1.5 * 60.0, true)
	await create_timer(3.0).timeout
	clock.set_earth_time(0.3, true)
	await _frames(20)
	check(not cut.playing(), "the next night it just opens, no cutscene")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	if game:
		game.hold_saves = true
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

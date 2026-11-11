extends SceneTree

# Checks who you meet and in what order (Hayden's 11 Nov 2026 meeting order, scripts/meetings.gd): Dash's stall shut
# until he's met, The Bike Boy all the way through (Dash's glowing tyre tracks and the three bits he dropped, his lab,
# the runaway Buzz Bot, his stall opening, the Gloop King and the crown, and Dash sending you on to Pip), the story
# quests following on straight away with no waiting for a new visit (Pip, then Bramble, then Melody and Heather, then
# Dash again), the Goals page without "Night N", a night's things coming out with its quest, and old saves (met Dash
# the old way).
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_meetings.gd
#
# Your own save is put aside (under its own name) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.meetings_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const Q := "bike_boy"

var failures := 0
var said: Array = []
var messages: Array = []
var clock: Node
var game: Node
var dialogue: Node
var quests: Node
var fn: Node
var meet: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(300.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	clock = root.get_node("Clock")
	game = root.get_node("Game")
	dialogue = root.get_node("Dialogue")
	quests = root.get_node("Quests")
	fn = root.get_node("FirstNight")
	_run.call_deferred()


func _step(id := Q) -> String:
	return str(quests.current_step(id).get("id", ""))


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	meet = fn.get_node("Meetings")
	dialogue.line_shown.connect(func(who: String, text: String) -> void: said.append([who, text]))
	game.message_posted.connect(func(t: String) -> void: messages.append(t))
	var shop := root.get_node("Shop")
	game.hold_saves = true
	game._resume = {}
	game.riding = false
	clock.pulls_home = false
	dialogue.reset()
	quests.reset()
	dialogue.flags["fresh_start"] = true
	clock.on_earth = false
	clock.set_time(2, 9 * 60.0, true)
	change_scene_to_file(TOWN)
	await _frames(10)
	await _physics(30)

	# --- Dash's stall is shut until you've met him ---
	check(not meet.stall_open(), "a new game: Dash's gadget stall is shut")
	var stall := _stall("Gadget")
	check(stall != null, "the gadget stall is in the Market Square")
	if stall:
		stall.use()
		await _frames(2)
		check(not shop.is_open() and dialogue.is_active(), "using it reads a sign instead of opening the shop")
		await _through()
		check(_said("GONE TINKERING"), "...\"GONE TINKERING. BACK SOON! -D\"")
	var dash := _talker("dash")
	if dash:
		var lines := await _talk_to(dash)
		check(_said_in(lines, "Can't stop"), "Dash only zooms past before you've met him")

	# --- The Bike Boy starts (Rex sends you), and is followed ---
	dialogue.set_flag("bike_boy_start")
	quests.check()
	await _frames(4)
	check(quests.is_started(Q) and _step() == "tracks", "The Bike Boy starts on Dash's tracks")
	check(quests.is_followed(Q), "...and it's followed by itself (a story quest)")
	await _physics(40)
	await _frames(30)
	var tracks := current_scene.get_node_or_null("Dash's Tyre Tracks") as Node3D
	check(tracks != null and tracks.get_child_count() > 40, "glowing tyre tracks lead from the Skate Park (%d marks)" %
		(tracks.get_child_count() if tracks else 0))
	if tracks:
		var low := 0
		for m in tracks.get_children():
			if (m as Node3D).global_position.y < -0.5:
				low += 1
		check(low == 0, "...lying on the ground, not under it")
	var stars: Array = root.get_node("TownMap").quest_markers()
	check(stars.size() >= 3, "a star for each bit he dropped (%d stars)" % stars.size())
	dash = _talker("dash")
	check(dash != null and _doing(dash) == "away", "Dash is off in his lab, out of sight: you can't find him yet")
	for i in 3:
		var part := current_scene.get_node_or_null("Dash's Gadget Bit %d" % (i + 1)) as Node3D
		check(part != null, "bit %d is out" % (i + 1))
		if part:
			_stand_at(part.global_position)
			await _physics(4)
			await _frames(3)
	check(dialogue.flags.has("bb_part_1") and dialogue.flags.has("bb_part_2") and dialogue.flags.has("bb_part_3"),
		"walking up to each bit picks it up")
	check(messages.any(func(m: String) -> bool: return m.contains("That's all three")), "...and the last one says where the tracks end")
	await _frames(30)
	check(_step() == "lab", "on to the lab (%s)" % _step())

	# --- The lab and the runaway Buzz Bot ---
	await _physics(30)
	dash = _talker("dash")
	check(dash != null and _going(dash, "lab"), "Dash is in his lab")
	check(dash != null and _doing(dash) != "away" and (dash.get_parent() as Node3D).visible and dash.monitoring,
		"...out where you can see him and talk to him")
	var lines := await _talk_to(dash) if dash else []
	check(_said_in(lines, "I'm Dash") and _said_in(lines, "Buzz Bot"), "Dash says hello, and his Buzz Bot gets loose")
	await _frames(30)
	check(_step() == "bot", "on to catching it (%s)" % _step())
	var bot := current_scene.get_node_or_null("Runaway Buzz Bot") as Node3D
	check(bot != null, "the Buzz Bot zooms round in front of the lab")
	if bot:
		var a: Vector3 = bot.global_position
		await _frames(30)
		check(bot.global_position.distance_to(a) > 0.2, "...really zooming")
		for i in 20:
			if not is_instance_valid(bot):
				break
			_stand_at(bot.global_position)
			await _physics(2)
	check(dialogue.flags.has("bb_bot_caught"), "walking into it catches it")
	await _frames(30)
	check(_step() == "thanks", "on to telling Dash (%s)" % _step())
	lines = await _talk_to(dash)
	check(_said_in(lines, "gadget stall") and _said_in(lines, "blueprint"), "Dash: his stall's open, and the Star Popper's blueprint blew away")
	await _frames(30)
	check(meet.stall_open(), "now Dash's stall is open")
	if stall:
		stall.use()
		await _frames(2)
		check(shop.is_open(), "...and his stall opens its shop")
		shop.close()
		await _frames(4)
	# The Star Popper's blueprint is in the Market Square (Schematics.LIST "popper"): walk into it, then buy it
	var bp := current_scene.get_node_or_null("Schematic popper") as Node3D
	check(bp != null or dialogue.flags.has("schematic_popper"), "the Star Popper's blueprint is out in the Market Square")
	if bp:
		_stand_at(bp.global_position)
		await _physics(8)
	if not root.get_node("Arsenal").owns("popper"):
		game.sparkles = maxi(game.sparkles, 3)
		check(shop.buy("star_popper"), "...and Dash builds the Star Popper")
	await _frames(30)
	check(dialogue.flags.has("bb_stall") and dialogue.flags.has("schematic_popper") and dialogue.flags.has("bb_popper"),
		"looked at the stall, found the blueprint and got a Star Popper (%s %s %s, owns %s)" % [dialogue.flags.has("bb_stall"),
		dialogue.flags.has("schematic_popper"), dialogue.flags.has("bb_popper"), root.get_node("Arsenal").owns("popper")])
	await _frames(30)
	check(_step() == "king", "on to the Gloop King (%s)" % _step())

	# --- The Gloop King ---
	await _physics(30)
	stars = root.get_node("TownMap").quest_markers()
	check(stars.any(func(s: Dictionary) -> bool: return Vector2(s.pos.x + 134, s.pos.z - 2).length() < 1.0), "a star on the King's court")
	var king := current_scene.find_child("The Gloop King", true, false)
	check(king != null, "the Gloop King is there")
	messages.clear()
	var guard := 40
	while king and not king.defeated and guard > 0:
		guard -= 1
		king.shot(1, king.global_position, Vector3.FORWARD)
		await _physics(2)
	await _frames(4)
	check(dialogue.flags.has("popped_gloop_king") and messages.any(func(m: String) -> bool: return m.contains("HOORAY")),
		"the Gloop King popped, with a cheer")
	dash = _talker("dash")
	lines = await _talk_to(dash)
	check(game.has_item("shop:gloop_crown") and str(game.outfit.get("head", "")) == "gloop_crown", "Dash gives the Gloop Crown")
	check(not _said_in(lines, "Agent of Chaos"), "...and doesn't spoil the Agent of Chaos")
	check(_said_in(lines, "Pip"), "...and sends you on to Pip")
	await _frames(30)
	check(quests.is_done(Q), "The Bike Boy is done")

	# --- The story follows on, straight away ---
	check(quests.is_started("night_2") and quests.is_followed("night_2"), "Pip's quest starts straight away, with no new visit (and is followed)")
	check(not str(quests.quest("night_2").name).contains("Night"), "...and its name doesn't say \"Night\" (%s)" % quests.quest("night_2").name)
	check(str(quests.current_step("night_2").text).contains("Dash says"), "...it says who sent you")
	var goals: Array = root.get_node("Nights").goals()
	check(str(goals[0][0]) == "Right now" and not str(goals[0][1][0]).contains("Night"), "the Goals page: \"Right now\", no night numbers")
	check(not fn.held_back(2), "a new game's night 2 things (S-K-A-T-E letters) come out with Pip's quest")
	await _skip_all("night_2")
	check(quests.is_started("night_3") and str(quests.current_step("night_3").text).contains("Pip says"), "then Bramble's, sent by Pip")
	await _skip_all("night_3")
	check(quests.is_started("meet_friends") and _step("meet_friends") == "melody", "then Melody and Heather")
	lines = await _talk("melody")
	check(_said_in(lines, "Heather") and dialogue.flags.has("mf_melody"), "Melody wants Heather to hear her new song")
	await _frames(30)
	lines = await _talk("clover")
	check(dialogue.flags.has("mf_heather") and _said_in(lines, "Heather"), "Heather's on her way")
	await _frames(30)
	lines = await _talk("melody")
	check(dialogue.flags.has("mf_song") and _said_in(lines, "Dash"), "Melody's song, and she sends you to Dash")
	await _frames(30)
	check(quests.is_done("meet_friends") and quests.is_started("night_4"), "then Dash's stars over Observatory Hill")
	check(str(quests.current_step("night_4").text).contains("Melody"), "...sent by Melody and Heather")

	# --- Old saves: met Dash the old way ---
	quests.reset()
	dialogue.reset()
	dialogue.flags["fn_met_dash"] = true
	dialogue.flags["fn_v2"] = true
	dialogue.flags["fn_v3"] = true
	dialogue.flags["first_night_start"] = true
	quests.state["first_night"] = {"step": 9, "since_day": clock.day, "done": false}       # (the old King step)
	fn.migrate()
	check(fn.step() == "home" and _step() == "king", "an old save on the King step: home for the First Night, the King in The Bike Boy")
	check(meet.stall_open(), "...and Dash's stall is open for it")
	quests.reset()
	dialogue.reset()
	dialogue.flags["fn_met_dash"] = true
	quests.state["first_night"] = {"step": 11, "since_day": clock.day, "done": true}
	fn.migrate()
	check(quests.is_done(Q), "an old save past the First Night: The Bike Boy's done")
	quests.reset()
	dialogue.reset()
	check(meet.stall_open(), "a save from before the new first day keeps Dash's stall")

	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	_finish()


func _skip_all(id: String) -> void:
	var guard := 20
	while quests.is_started(id) and not quests.is_done(id) and guard > 0:
		guard -= 1
		quests.skip(id)
		await _frames(2)
	await _frames(4)


func _stall(which: String) -> Node:
	for n in current_scene.find_children("*", "Area3D", true, false):
		if str(n.get("stall")) == which:
			return n
	return null


func _through() -> void:
	var guard := 100
	while dialogue.is_active() and guard > 0:
		guard -= 1
		dialogue._finish_typing()
		dialogue._next()
		await _frames(1)
	await create_timer(0.25).timeout


func _stand_at(at: Vector3) -> void:
	var p := current_scene.find_child("Player", true, false) as CharacterBody3D
	p.global_position = at + Vector3(0, 0.3, 0)
	p.velocity = Vector3.ZERO


func _talker(id: String) -> Area3D:
	for t in current_scene.find_children("Talk", "Area3D", true, false):
		if t.get("character_id") == id:
			return t
	return null


func _going(t: Node, place: String) -> bool:
	for n in get_nodes_in_group("routines"):
		if n.get("character_id") == t.get("character_id"):
			return str(n.current_block().get("place", "")) == place
	return false


func _doing(t: Node) -> String:
	for n in get_nodes_in_group("routines"):
		if n.get("character_id") == t.get("character_id"):
			return str(n.current_block().get("do", ""))
	return ""


func _said(text: String) -> bool:
	return _said_in(said, text)


func _said_in(lines: Array, text: String) -> bool:
	return lines.any(func(l: Array) -> bool: return str(l[1]).contains(text))


func _talk(id: String) -> Array:
	var t := _talker(id)
	if t == null:
		print("      (no %s here)" % id)
		return []
	return await _talk_to(t)


func _talk_to(t: Node3D) -> Array:
	if t == null:
		return []
	var player := current_scene.find_child("Player", true, false) as CharacterBody3D
	var body := t.get_parent() as Node3D
	player.global_position = body.global_position + body.global_basis.z * 1.6 + Vector3(0, 0.8, 0)
	player.velocity = Vector3.ZERO
	for i in 4:
		await physics_frame
	said.clear()
	dialogue.talk_to(t)
	await _frames(2)
	var guard := 300
	while dialogue.is_active() and guard > 0:
		guard -= 1
		if dialogue._choosing:
			dialogue.current_choices()[0].pressed.emit()
		else:
			dialogue._finish_typing()
			dialogue._next()
		await _frames(1)
	await create_timer(0.25).timeout
	return said.duplicate()


func _finish() -> void:
	game.hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit(failures)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame

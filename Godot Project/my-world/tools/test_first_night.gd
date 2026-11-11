extends SceneTree

# Walks the whole of "The First Night" (res://quests/first_night.json, scripts/first_night.gd), from a new game to
# waking up at home the next night: the hero's made at 8 PM on Earth, Nina knocks, Mr. Palmer and two more people on
# the green, the evening waits at 11 PM until that's done, the bed's "Until the Shift", the portal and the arrival
# moment (the swirl, the watch on their wrist), Dash at the portal, the Void day (Star Popper and three Gloops,
# Dash's gadget stall, Rex and Coach Bruno's first two lesson steps, a request, the fountain's lost watch, Zippy), the
# Gloop King and the crown from Dash, then pulled home at the end of the Shift into bed, and Nina's "Same time
# tomorrow?". The Shift is fast-forwarded. Then: every step can be skipped from the quest log, an old save is
# offered it (never forced), the quest log has the buttons, and it all saves and loads.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_first_night.gd
#
# Your own save is put aside (under its own name, so another test can't swap it) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.first_night_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"
const Q := "first_night"

var failures := 0
var clock: Node
var game: Node
var dialogue: Node
var quests: Node
var fn: Node
var said: Array = []
var messages: Array = []


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(300.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_put_save_back()
		quit(1))
	clock = root.get_node("Clock")
	game = root.get_node("Game")
	dialogue = root.get_node("Dialogue")
	quests = root.get_node("Quests")
	fn = root.get_node("FirstNight")
	_run.call_deferred()


func _step() -> String:
	return str(quests.current_step(Q).get("id", ""))


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	dialogue.line_shown.connect(func(who: String, text: String) -> void: said.append([who, text]))
	game.message_posted.connect(func(t: String) -> void: messages.append(t))
	var creator := root.get_node("Creator")
	var lesson := root.get_node("SkateLesson")
	var shop := root.get_node("Shop")
	var requests := root.get_node("Requests")
	var watches := root.get_node("Watches")

	var oak_mod := root.get_node("HummingOak")
	# --- A new game: the hero's made, and it's 9 AM on Earth ---
	game.new_game()
	await _wait_for_scene(EARTH)
	await _frames(10)
	check(not quests.is_started(Q), "before the hero's made, the First Night hasn't started")
	if not creator.is_open():
		creator.open(true)
	await _frames(3)
	game.hero["name"] = "Sunny"
	clock.earth_minutes = 22 * 60.0                         # (the clock kept going while they were in the creator)
	creator.close()
	await _frames(6)
	check(quests.is_started(Q) and _step() == "morning", "making the hero starts The First Night, on its first step")
	check(absf(clock.earth_minutes - 9 * 60.0) < 2.0, "...at 9 AM on Earth: a sunny morning, whatever time the creator took (%s)" % clock.earth_time_string())
	check(messages.any(func(m: String) -> bool: return m.contains("Knock knock")), "Nina knocks at the door")
	check(not oak_mod.awake(), "the old oak is just a tree for now")
	await _physics(30)
	var nina := _talker("nina_earth")
	var green_s := _place("green_s")
	check(nina != null and _flat(nina.get_parent().global_position - green_s) < 3.0,
		"Nina waits on the green, right outside the house (%.1f m)" % (_flat(nina.get_parent().global_position - green_s) if nina else -1.0))
	var stars: Array = root.get_node("TownMap").quest_markers()
	check(stars.size() >= 2, "the map has stars for who to see (%d)" % stars.size())

	var lines := await _talk("nina_earth")
	check(_said(lines, "hums") and _said(lines, "midnight"), "Nina: the old oak hums at midnight")
	check(not _said(lines, "{"), "...every {word} filled in")
	check(dialogue.flags.has("fn_nina") and _said(lines, "Sunny"), "...and she uses the hero's name")
	var palmer := _talker("palmer_earth")
	check(palmer != null and _flat(palmer.get_parent().global_position - _place("gazebo")) < 4.0, "Mr. Palmer is by the gazebo")
	lines = await _talk("palmer_earth")
	check(dialogue.flags.has("fn_palmer") and _said(lines, "opens your menu") and _said(lines, "map"),
		"Mr. Palmer teaches talking, the map and the menu")
	# The day waits for a slow first look round
	clock.earth_minutes = 19 * 60.0 + 20.0
	await _frames(4)
	check(absf(clock.earth_minutes - 18 * 60.0) < 0.5, "Earth's clock waits at 6 PM until the day's clues are found (%s)" % clock.earth_time_string())
	clock.earth_minutes = 10 * 60.0
	check(not root.get_node("FirstNight").shift_sleep_ok(), "...and the bed doesn't offer \"Until the Shift\" yet")
	lines = await _talk("theo")
	check(_step() == "morning" and not dialogue.flags.has("fn_folk"), "one hello isn't two")
	lines = await _talk("lionel")
	await _frames(4)
	check(dialogue.flags.has("fn_folk") and _step() == "board", "two hellos on the green: on to the notice board")

	# --- The notice board tutorial (Hayden's 11 Nov 2026 playtest) ---
	var jobs := root.get_node("EarthJobs")
	var nb := current_scene.get_node_or_null("Notice Board") as Node3D
	check(nb != null, "the notice board is up on a new game's first morning")
	check(jobs.is_live() and jobs.list.size() == 3, "...with three jobs on it (%d)" % jobs.list.size())
	await _physics(30)
	nina = _talker("nina_earth")
	check(nina != null and _going(nina, "gazebo"), "Nina goes to the board by the gazebo")
	lines = await _talk("nina_earth")
	check(_said(lines, "notice board"), "Nina: come and see the notice board")
	stars = root.get_node("TownMap").quest_markers()
	check(stars.any(func(q: Dictionary) -> bool: return _flat(q.pos - nb.global_position) < 1.0), "a star on the board")
	lines = await _talk_to(nb.get_node("Request Talk"), [0])
	check(_said(lines, "FOLLOW") and dialogue.flags.has("fn_board_look"), "reading it: Nina explains following and turning in")
	var first_key: String = jobs.key_of(jobs.list[0])
	check(quests.is_followed(first_key) and dialogue.flags.has("fn_board_follow"), "...and the board's choice follows a job (%s)" % first_key)
	check(not root.get_node("TownMap").quest_markers().is_empty(), "the followed job has stars on the map")
	jobs.list[0].progress = jobs.list[0].goal
	jobs.list[0].done = true
	jobs.changed.emit()
	await _frames(2)
	check(_step() == "board", "a finished job still has to be turned in")
	lines = await _talk_to(nb.get_node("Request Talk"), [-1])
	await _frames(4)
	check(jobs.list[0].paid and dialogue.flags.has("fn_board_job"), "turned in at the board: paid")
	check(_step() == "oak", "on to the old oak")

	# --- The Humming Oak: listen, three clues, three acorns ---
	await _physics(30)
	nina = _talker("nina_earth")
	check(nina != null and _going(nina, "old_oak"), "Nina goes to wait by the old oak")
	var spot := current_scene.find_child("Oak Spot", true, false)
	check(spot != null, "the old oak has a spot to listen at")
	lines = await _talk_to(spot)
	check(_said(lines, "ticking") and dialogue.flags.has("fn_oak_listen"), "listening to the oak: something's ticking inside")
	await _frames(4)
	check(_step() == "clues", "on to the clues")
	for i in 3:
		check(current_scene.get_node_or_null("Glowing Acorn %d" % (i + 1)) != null, "glowing acorn %d is out" % (i + 1))
	stars = root.get_node("TownMap").quest_markers()
	check(stars.size() >= 5, "the map has stars for Mr. Page, the envelope and all three acorns (%d)" % stars.size())
	await _physics(30)
	check(_going(_talker("lionel"), "bookshop"), "Mr. Page is back at his bookshop")
	lines = await _talk("lionel")
	check(dialogue.flags.has("fn_book") and _said(lines, "LEGEND OF THE OLD OAK") and _said(lines, "three acorns"),
		"Mr. Page's book: The Legend of the Old Oak, and three acorns of light")
	var town := root.get_node("EarthTown")
	lines = []
	for l in town.letter_lines():
		lines.append(["", l])
	check(dialogue.flags.has("read_palmer_letter") and _said(lines, "THE VOID"), "Mr. Palmer's envelope, from the Void")
	var felt: int = town.tremors_felt
	var p := current_scene.find_child("Player", true, false) as CharacterBody3D
	for i in 3:
		var acorn := current_scene.get_node_or_null("Glowing Acorn %d" % (i + 1)) as Node3D
		if acorn:
			p.global_position = acorn.global_position + Vector3(0, 0.3, 0)
			await _physics(8)
	await _frames(4)
	check(dialogue.flags.has("fn_acorns") and town.tremors_felt == felt + 3, "all three acorns found, and each one set off a tremor")
	check(_step() == "dusk", "on to dusk: the acorns go in the oak's roots")
	clock.earth_minutes = 23 * 60.0 + 30.0
	await _frames(4)
	check(absf(clock.earth_minutes - 23 * 60.0) < 0.5 and not clock.in_shift(),
		"Earth's clock waits at 11 PM until they're in (%s)" % clock.earth_time_string())
	clock.earth_minutes = 18 * 60.0 + 30.0
	lines = await _talk_to(spot)
	check(dialogue.flags.has("fn_acorns_placed") and _said(lines, "runes"), "the acorns go in the nook, and the runes wake")
	await _frames(4)
	check(_step() == "wait" and not oak_mod.awake(), "on to waiting for midnight (the oak's not open yet)")
	lines = await _talk("nina_earth")
	check(_said(lines, "Until midnight") and root.get_node("FirstNight").shift_sleep_ok(), "Nina suggests the bed's \"Until midnight\"")

	# --- The bed: Until the Shift ---
	var bed := current_scene.find_child("SleepSpot", true, false)
	check(bed != null, "the bed is there")
	bed.sleep_for(clock.minutes_until_hour(0))
	await create_timer(5.5).timeout
	await _frames(4)
	check(clock.in_shift() and _step() == "awaken", "slept until the Shift: it's midnight (%s, %s)" % [clock.earth_time_string(), _step()])
	var door := current_scene.find_child("PortalToGalaxity", true, false) as Node3D
	check(str(door.get("closed_message")) != "", "...but the oak's door doesn't open till they go and see it")
	# --- The reveal ---
	p = current_scene.find_child("Player", true, false) as CharacterBody3D
	p.global_position = door.global_position + door.global_basis.z * 8.0
	await _frames(6)
	check(oak_mod.revealing and get_root().get_viewport().get_camera_3d().name == "Oak Reveal Camera", "walking up at midnight: the oak wakes (the camera swings round to it)")
	check(p.get("input_locked") == true, "...and they stand and watch")
	await create_timer(oak_mod.REVEAL_TIME + 0.5).timeout
	check(not oak_mod.revealing and dialogue.flags.has("oak_woken") and p.get("input_locked") == false, "the reveal ends, and off they go")
	check(get_root().get_viewport().get_camera_3d() == p.find_child("Camera3D", true, false), "...with their own camera back")
	await _frames(4)
	check(_step() == "shift" and oak_mod.awake() and str(door.get("closed_message")) == "", "the door in the oak is open")
	var swirl := current_scene.find_child("Portal Swirl", true, false) as Node3D
	check(swirl.visible, "...and swirling")
	lines = await _talk("nina_earth")
	check(_said(lines, "walk right into it"), "Nina: go on, into the oak")

	# --- Through the portal: the arrival moment ---
	var watch_before: bool = game.has_item("shop:shift_watch")
	game.go(TOWN, "FromPortaltoEarth")
	await _wait_for_scene(TOWN)
	await _frames(3)
	check(not watch_before and game.has_item("shop:shift_watch") and str(game.outfit.get("hands", "")) == "shift_watch",
		"a watch appears on the hero's wrist")
	check(fn.is_arriving() and fn._warp_layer.visible, "the screen swirls as they land")
	check(fn._warp_text.text.contains("Dawn"), "...\"%s\"" % fn._warp_text.text.replace("\n", " "))
	p = current_scene.find_child("Player", true, false)
	check(p.get("input_locked") == true, "...and they stand still for it")
	await create_timer(fn.WARP_TIME + 1.6).timeout
	check(not fn.is_arriving() and not fn._warp_layer.visible and p.get("input_locked") == false, "then it clears, and off they go")
	check(clock.in_shift() and clock.hour() == 7 or clock.hour() == 8, "it's dawn in the Void (%s)" % clock.time_string())
	var piece: Node3D = Clothes.hat_or_piece("hands", "shift_watch")
	check(piece != null, "the Shift Watch has a look of its own")
	if piece:
		piece.free()
	await _physics(30)
	var dash := _talker("dash")
	check(dash != null and _flat(dash.get_parent().global_position - _place("portal")) < 4.0, "Dash waits by the portal")
	lines = await _talk("dash")
	check(_said(lines, "outside of time") and _said(lines, "chosen"), "Dash: a planet outside time, and some people are chosen")
	check(_step() == "day", "on to the Void day")

	# --- The Void day ---
	await _physics(30)
	dash = _talker("dash")
	check(_going(dash, "market"), "Dash heads to the Market Square, by his stall")
	lines = await _talk("dash")
	check(dialogue.flags.has("fn_popper") and _said(lines, "Star Popper"), "Dash hands over the Star Popper")
	check(_said(lines, "gadget stall") and _said(lines, "Rex") and _said(lines, "Tally") and _said(lines, "Zippy") and _said(lines, "fountain"),
		"...and points out his stall, Rex, Tally, Zippy and the fountain's watch")
	for i in 3:
		requests.note("gloop", 1.0, "bubble")
	check(dialogue.flags.has("fn_gloops"), "three Gloops popped")
	shop.open("Gadget")
	await _frames(2)
	shop.close()
	await _frames(2)
	check(dialogue.flags.has("fn_stall"), "looked at Dash's gadget stall")
	game.items.erase("skateboard")
	var rex := _talker("rex")
	check(rex != null and _going(rex, "skate_park"), "Rex is at the Skate Park")
	lines = await _talk("rex")
	check(game.has_item("skateboard") and _said(lines, "spare"), "Rex lends a skateboard if they haven't got one")
	await _frames(6)
	check(lesson.active, "...and Coach Bruno's lesson starts")
	lesson.complete("push")
	await create_timer(2.0).timeout                          # (Rook's praise between steps)
	lesson.complete("ollie")
	await _frames(4)
	lesson.stop()
	game.riding = false
	check(dialogue.flags.has("skate_lesson_push") and dialogue.flags.has("skate_lesson_ollie"), "pushed and popped an ollie")
	check(requests.list.size() == 3 and requests.list.any(func(r: Dictionary) -> bool: return r.tier == "easy"),
		"Tally's board has an easy request")
	requests.list[0].done = true
	requests.changed.emit()
	await _frames(2)
	check(dialogue.flags.has("fn_request"), "a request finished")
	watches.pick_up("water_clock")
	await _frames(2)
	check(dialogue.flags.has("fn_fountain_watch"), "the lost watch on the fountain found")
	lines = await _talk("dash")
	check(watches.given_count() >= 1, "...and Dash takes it first, before anything else he has to say")
	var zippy := _starter()
	check(zippy != null, "Zippy is at the Lake Loop")
	if zippy:
		lines = await _talk_to(zippy, [-1])
		check(_said(lines, "Zippy") or _said(lines, "Vroom"), "Zippy says hi")
	await _frames(4)
	check(_step() == "king", "every part of the day done: on to the Gloop King (%s)" % _step())

	# --- The Gloop King ---
	await _physics(30)
	dash = _talker("dash")
	check(_going(dash, "market_far_west"), "Dash waits at the edge of the west fields")
	stars = root.get_node("TownMap").quest_markers()
	check(stars.any(func(s: Dictionary) -> bool: return _flat(s.pos - Vector3(-134, 0, 2)) < 1.0), "a star on the King's court")
	lines = await _talk("rex")
	check(_said(lines, "west fields"), "rumours lead to the west fields")
	var king := current_scene.find_child("The Gloop King", true, false)
	check(king != null, "the Gloop King is there")
	messages.clear()
	var guard := 40
	while king and not king.defeated and guard > 0:
		guard -= 1
		king.shot(1, king.global_position, Vector3.FORWARD)
		await _physics(2)
	await _frames(4)
	check(dialogue.flags.has("popped_gloop_king"), "the Gloop King popped")
	check(messages.any(func(m: String) -> bool: return m.contains("HOORAY")), "...with a cheer")
	var sparkles: int = game.sparkles
	lines = await _talk("dash")
	check(not _said(lines, "Agent of Chaos") and _said(lines, "flickers"), "Dash only hints (the sky flickers): no Agent of Chaos yet")
	check(game.has_item("shop:gloop_crown") and str(game.outfit.get("head", "")) == "gloop_crown" and game.sparkles == sparkles + 15,
		"the reward: the Gloop Crown, worn straight away, and 15 sparkles")
	var crown: Node3D = Cosmetics.hat("gloop_crown")
	check(crown != null, "the Gloop Crown has a look of its own")
	check(_step() == "home", "on to going home")
	await _frames(4)
	check(clock.pull_spawn == "HomeSpawn", "tonight the end of the Shift puts them to bed")
	if crown:
		crown.free()

	# --- Pulled home ---
	clock.pulls_home = true
	clock.end_shift()
	await _wait_for_scene(EARTH, 240)
	await _frames(10)
	var spawn := current_scene.find_child("HomeSpawn", true, false) as Node3D
	p = current_scene.find_child("Player", true, false)
	check(current_scene.scene_file_path == EARTH and p.global_position.distance_to(spawn.global_position) < 1.5,
		"pulled home at 1 AM, waking up in bed")
	check(messages.any(func(m: String) -> bool: return m.contains("wakes up in bed")), "\"...wakes up in bed, back on Earth\"")
	await _physics(30)
	sparkles = game.sparkles
	lines = await _talk("nina_earth")
	check(_said(lines, "Same time tomorrow?"), "Nina: \"Same time tomorrow?\"")
	await _frames(4)
	check(quests.is_done(Q) and game.sparkles == sparkles + 10, "The First Night is done (+10 sparkles)")
	check(clock.pull_spawn == "", "...and the portal goes back to leaving them by the oak")

	# --- Saved and loaded ---
	game.save_game()
	var keep: Dictionary = quests.save_data()
	quests.reset()
	game.load_game()
	check(quests.is_done(Q) and quests.save_data() == keep, "it all saves and loads")

	# --- Every step can be skipped from the quest log ---
	quests.reset()
	for f in dialogue.flags.keys():
		if str(f).begins_with("fn_") or str(f) in ["first_night_start", "oak_woken"]:
			dialogue.flags.erase(f)
	fn.start()
	await _frames(2)
	var menu := root.get_node("PlayerMenu")
	menu.open("quests")
	await _frames(3)
	var skip := menu.find_child("Skip " + Q, true, false) as Button
	check(skip != null, "the quest log has a Skip button")
	var seen := []
	guard = 14
	while quests.is_started(Q) and not quests.is_done(Q) and guard > 0:
		guard -= 1
		seen.append(_step())
		skip = menu.find_child("Skip " + Q, true, false) as Button
		if skip == null:
			break
		skip.pressed.emit()
		await _frames(3)
	check(quests.is_done(Q) and seen == ["morning", "board", "oak", "clues", "dusk", "wait", "awaken", "shift", "day", "king", "home"],
		"every step skips, one at a time (%s)" % ", ".join(seen))
	menu.close()
	await _frames(2)

	# --- An old save: offered, never forced ---
	quests.reset()
	for f in dialogue.flags.keys():
		if str(f).begins_with("fn_") or str(f) in ["first_night_start", "oak_woken"]:
			dialogue.flags.erase(f)
	await _frames(4)
	check(not quests.is_started(Q), "an old save doesn't get it by itself")
	menu.open("quests")
	await _frames(3)
	check(menu.find_child("Start " + Q, true, false) != null, "the quest log offers it")
	menu.close()
	await _frames(2)
	lines = await _talk("nina_earth", [1])
	check(_said(lines, "first night all over again") and not quests.is_started(Q), "Nina offers it, and \"no thanks\" is fine")
	lines = await _talk("nina_earth")
	check(not _said(lines, "first night all over again"), "...she only asks once")
	dialogue.flags.erase("fn_offered")
	lines = await _talk("nina_earth", [0])
	await _frames(4)
	check(quests.is_started(Q) and _step() == "morning" and dialogue.flags.has("fn_nina"), "...and \"yes\" starts it, with Nina already met")

	_put_save_back()
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)


func _put_save_back() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")


# -----------------------------------------------------------------------------
func _talker(id: String) -> Area3D:
	for t in current_scene.find_children("Talk", "Area3D", true, false):
		if t.get("character_id") == id:
			return t
	return null


func _starter() -> Node3D:
	# Zippy's talk spot at the Lake Loop (scripts/races.gd)
	for t in current_scene.find_children("*", "Area3D", true, false):
		if t.get_parent() and str(t.get_parent().get_meta("track_id", "")) == "lake_loop" and t.has_method("begin_talk"):
			return t
	return null


func _going(t: Node, place: String) -> bool:
	# Their routine has them at (or on the way to) this place
	var r := t.get_parent().find_child("Routine", true, false)
	if r == null:
		for n in get_nodes_in_group("routines"):
			if n.get("character_id") == t.get("character_id"):
				r = n
	return r != null and str(r.current_block().get("place", "")) == place


func _place(id: String) -> Vector3:
	var paths := TownPaths.get_shared(TownPaths.EARTH_FILE if clock.on_earth else TownPaths.FILE)
	var v: Vector2 = paths.points.get(id, Vector2.ZERO)
	return Vector3(v.x, 0, v.y)


func _said(lines: Array, text: String) -> bool:
	return lines.any(func(l: Array) -> bool: return str(l[1]).contains(text))


func _talk(id: String, picks: Array = []) -> Array:
	var t := _talker(id)
	if t == null:
		print("      (no %s here)" % id)
		return []
	return await _talk_to(t, picks)


func _talk_to(t: Node3D, picks: Array = []) -> Array:
	# Stand by them and talk it all the way through, picking answers (-1: the last one)
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
			var buttons: Array = dialogue.current_choices()
			var pick: int = picks.pop_front() if picks.size() > 0 else 0
			buttons[pick if pick >= 0 else buttons.size() - 1].pressed.emit()
		else:
			dialogue._finish_typing()
			dialogue._next()
		await _frames(1)
	await create_timer(0.25).timeout
	return said.duplicate()


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _wait_for_scene(path: String, frames := 200) -> void:
	for i in frames:
		await process_frame
		if current_scene and current_scene.scene_file_path == path:
			break
	await _frames(6)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame

extends SceneTree

# Walks the whole of "The First Night" (res://quests/first_night.json, scripts/first_night.gd), from a new game to
# waking up at home the next night: the hero's made, it's 9 AM on Earth, Nina knocks, Mr. Palmer and two more people
# on the green, the notice board, the evening (nothing about midnight), a sleep that stops at midnight, the ground
# cracking open under them, the night the sky cracked (the watch on their wrist, seven landings, the little aliens,
# the cutscene), Tally's rattled hello in the Market Square, the Void day (three Gloops, Rex
# and Coach Bruno's first two lesson steps, Rex sending them after Dash, a request, the fountain's lost watch, Zippy),
# then pulled home at the end of the Shift into bed, and Nina's "Same time tomorrow?". (Meeting Dash and the Gloop
# King are The Bike Boy's now: tools/test_meetings.gd.) The Shift is fast-forwarded. Then: every step can be skipped from the quest log, an old save is
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
	# (Hayden's 12 Nov 2026 playtest: the opening is a cutscene and the movement tutorial, no pop-ups: scripts/opening.gd)
	check(dialogue.flags.has("opening_wake") and fn.opening.tutorial.running(), "Nina knocks at the door, and the movement tutorial starts")
	check(not messages.any(func(m: String) -> bool: return m.contains("Knock knock") or m.contains("Welcome") or m.contains("New jobs")),
		"...with no pop-up messages (%s)" % str(messages))
	check(not oak_mod.awake(), "the old oak is just a tree for now")
	await _physics(30)
	var nina := _talker("nina_earth")
	var green_s := _place("green_s")
	check(nina != null and _flat(nina.get_parent().global_position - green_s) < 3.0,
		"Nina waits on the green, right outside the house (%.1f m)" % (_flat(nina.get_parent().global_position - green_s) if nina else -1.0))
	var stars: Array = root.get_node("TownMap").quest_markers()
	check(stars.size() >= 2, "the map has stars for who to see (%d)" % stars.size())

	var lines := await _talk("nina_earth")
	check(not _said(lines, "midnight") and not _said(lines, "oak"), "Nina says nothing about the oak or midnight (no spoilers)")
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
	check(absf(clock.earth_minutes - 18 * 60.0) < 0.5, "Earth's clock waits at 6 PM until the town and the board are done (%s)" % clock.earth_time_string())
	clock.earth_minutes = 10 * 60.0
	check(not root.get_node("FirstNight").shift_sleep_ok(), "...and nothing offers a way to the Void yet")
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
	check(_step() == "evening", "on to the evening")

	# --- The evening: nothing says what's coming ---
	await _physics(10)
	lines = await _talk("nina_earth")
	check(_said(lines, "spaghetti") and not _said(lines, "midnight"), "Nina goes home for dinner, and says nothing about midnight")
	check(not oak_mod.awake(), "the old oak is still just a tree")
	var spot := current_scene.find_child("Oak Spot", true, false)
	check(spot != null, "the old oak has a spot to look at")
	lines = await _talk_to(spot)
	check(_said(lines, "big old oak") and not dialogue.flags.has("oak_woken"), "looking at it: a big old oak, nothing more")
	check(current_scene.get_node_or_null("Glowing Acorn 1") == null, "no glowing acorns (the oak's quest is gone)")
	check(not fn.shift_sleep_ok() and fn.sleep_stops_at_midnight(), "the bed offers no \"Until midnight\", but tonight any sleep stops there")
	clock.earth_minutes = 23 * 60.0 + 30.0
	await _frames(4)
	check(absf(clock.earth_minutes - (23 * 60.0 + 30.0)) < 1.0, "the evening isn't held up: the clock runs on (%s)" % clock.earth_time_string())
	check(not messages.any(func(m: String) -> bool: return m.contains("portal") or m.contains("Shift")), "...and no message mentions the portal or the Shift")

	# --- The bed, "until morning"... and the floor cracks open at midnight ---
	var bed := current_scene.find_child("SleepSpot", true, false)
	check(bed != null, "the bed is there")
	clock.earth_minutes = 21 * 60.0
	check(bed.call("_morning_stops") == true, "\"Until morning\" stops at midnight tonight")
	var watch_before: bool = game.has_item("shop:shift_watch")
	bed.sleep_for(clock.minutes_until_hour(7), bed.call("_morning_stops"))
	await create_timer(5.5).timeout
	check(clock.in_shift(), "she wakes at midnight (%s)" % clock.earth_time_string())
	await _wait_for_scene(TOWN, 240)
	await _frames(4)
	check(dialogue.flags.has("fn_fell") and dialogue.flags.has("oak_woken"), "midnight: the ground cracks open under them, and they fall")
	check(_step() == "shift" and oak_mod.awake(), "...into the Void (%s)" % _step())

	# --- The night the sky cracked ---
	var arrival: Node = fn.arrival
	check(not watch_before and game.has_item("shop:shift_watch") and str(game.outfit.get("hands", "")) == "shift_watch",
		"a watch appears on the hero's wrist")
	var p := current_scene.find_child("Player", true, false) as CharacterBody3D
	var lands := Vector3(arrival.HERO_LANDS.x, p.global_position.y, arrival.HERO_LANDS.y) as Vector3
	check(_flat(p.global_position - lands) < 2.0, "they land in the Market Square (%.1f m off)" % _flat(p.global_position - lands))
	check(clock.in_shift() and (clock.hour() == 7 or clock.hour() == 8), "it's dawn in the Void (%s)" % clock.time_string())
	check(arrival.sky_cracks.size() == 7, "seven cracks in the sky (%d)" % arrival.sky_cracks.size())
	check(arrival.greeters.size() == arrival.GREETERS, "little aliens come to greet them (%d)" % arrival.greeters.size())
	var round_hero: int = arrival.greeters.filter(func(g: Node3D) -> bool: return _flat(g.global_position - p.global_position) < 3.5).size()
	check(round_hero >= arrival.HERO_GREETERS - 1, "...%d of them round the hero" % round_hero)
	await _physics(30)
	for a in arrival.ARRIVALS:
		var t := _talker(str(a[0]))
		var near := t != null and _flat(t.get_parent().global_position - Vector3(a[2].x, 0, a[2].y)) < 1.5
		check(near and _going(t, "arrival_" + str(a[0])), "%s landed with them, at the square" % a[1])
	for id in arrival.ONLOOKERS:
		var t := _talker(id)
		check(t != null and _going(t, "arrival_" + ("palmer" if id == "mr_palmer" else id)), "%s stops to stare" % id)
	lines = await _talk("rex")
	check(_said(lines, "Totally normal") and not _said(lines, "Swap"), "Rex: \"totally normal\" (a hint, nothing more)")
	lines = await _talk("nina")
	check(_said(lines, "floor cracked") and _said(lines, "watch"), "Nina fell too, through her bedroom floor")
	var tally := current_scene.get_node_or_null("Tally") as Node3D
	check(tally != null and _flat(tally.global_position - arrival.tally_spot()) < 1.0, "Tally waits right beside them")
	stars = root.get_node("TownMap").quest_markers()
	check(stars.any(func(s: Dictionary) -> bool: return _flat(s.pos - _place("market")) < 3.0), "a star on the Market Square, for Tally")

	# --- The cutscene itself (headless runs skip the pictures unless asked) ---
	for f in ["fn_arrived"]:
		dialogue.flags.erase(f)
	arrival.force = true
	arrival.arrive()
	await _frames(3)
	check(arrival.playing() and get_root().get_viewport().get_camera_3d().name == "Arrival Camera", "the cutscene plays with its own camera")
	p = current_scene.find_child("Player", true, false) as CharacterBody3D
	check(p.get("input_locked") == true and not p.visible, "...the hero stands still, not landed yet")
	arrival._t = arrival.T_ALIENS + 1.0
	await create_timer(1.0).timeout
	check(p.visible and _talker("pip").get_parent().visible, "...everyone's landed by the time the little aliens come")
	check(arrival.greeters.any(func(g: Node3D) -> bool: return g.visible and not g.get_meta("there", false)), "...and the little aliens come running")
	arrival._t = arrival.LENGTH
	await _frames(4)
	check(not arrival.playing() and p.get("input_locked") == false and get_root().get_viewport().get_camera_3d() == p.find_child("Camera3D", true, false),
		"it ends: their own camera back, free to move")
	check(arrival.greeters.all(func(g: Node3D) -> bool: return g.get_meta("there", false)), "...with every little alien where it was going")
	arrival.force = false

	tally = current_scene.get_node_or_null("Tally/Request Talk") as Node3D
	check(tally != null, "Tally's in the Market Square")
	lines = await _talk_to(tally) if tally else []
	check(dialogue.flags.has("fn_met_tally") and _said(lines, "SEVEN"), "Tally: \"Seven. SEVEN! Out of the SKY!\"")
	check(_said(lines, "chosen") and _said(lines, "request"), "...says it's never happened, and shows the request board")
	check(_said(lines, "Rex") and _said(lines, "Skate Park"), "...and sends them on to Rex at the Skate Park")
	check(_said(lines, "Gloops"), "...and says how to pop Gloops: jump on them")
	await create_timer(3.5).timeout
	check(arrival.greeters.is_empty() and arrival.sky_cracks.is_empty(), "then the little aliens scatter and the sky closes")
	check(_step() == "day", "on to the Void day")
	check(not dialogue.flags.has("fn_met_dash"), "Dash isn't waiting at the portal any more (he's busy: The Bike Boy)")

	# --- The Void day ---
	await _physics(30)
	for i in 3:
		requests.note("gloop", 1.0, "stomp")
	check(dialogue.flags.has("fn_gloops"), "three Gloops popped")
	game.items.erase("skateboard")
	var rex := _talker("rex")
	check(rex != null and _going(rex, "skate_park"), "Rex is at the Skate Park")
	lines = await _talk("rex")
	check(_said(lines, "Tally says"), "Rex: Tally sent you")
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
	lines = await _talk("rex")
	check(_said(lines, "twin") and _said(lines, "tyre tracks") and dialogue.flags.has("bike_boy_start"),
		"after the ollie Rex sends them after his twin, Dash")
	await _frames(4)
	check(quests.is_started("bike_boy") and quests.is_followed("bike_boy"), "...The Bike Boy starts, and is followed with the First Night")
	check(requests.list.size() == 3 and requests.list.any(func(r: Dictionary) -> bool: return r.tier == "easy"),
		"Tally's board has an easy request")
	requests.list[0].done = true
	requests.changed.emit()
	await _frames(2)
	check(dialogue.flags.has("fn_request"), "a request finished")
	watches.pick_up("water_clock")
	await _frames(4)
	check(dialogue.flags.has("fn_fountain_watch"), "the lost watch on the fountain found")
	check(_step() == "home", "every part of the day done: on to going home (%s)" % _step())
	await _frames(4)
	check(clock.pull_spawn == "HomeSpawn", "tonight the end of the Shift puts them to bed")

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
	var sparkles: int = game.sparkles
	lines = await _talk("nina_earth")
	check(_said(lines, "FALL too") and _said(lines, "in front of the old oak went CRACK"), "Nina: \"Did you FALL too?\", and the ground by the old oak cracked too")
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
	var guard := 14
	while quests.is_started(Q) and not quests.is_done(Q) and guard > 0:
		guard -= 1
		seen.append(_step())
		skip = menu.find_child("Skip " + Q, true, false) as Button
		if skip == null:
			break
		skip.pressed.emit()
		await _frames(3)
	check(quests.is_done(Q) and seen == ["morning", "board", "evening", "shift", "day", "home"],
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
	# Zippy's talk spot at the race gate by the lake (scripts/races.gd HUBS: the races have circuits of their own)
	for t in current_scene.find_children("*", "Area3D", true, false):
		if t.get_parent() and str(t.get_parent().get_meta("hub_id", "")) == "void" and t.has_method("begin_talk"):
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

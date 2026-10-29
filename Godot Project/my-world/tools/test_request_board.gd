extends SceneTree

# Checks the nightly request board (scripts/requests.gd, request_board.gd, request_alien.gd, request_parcel.gd):
# each Shift rolls three requests, one easy, one medium and one harder, never the same kind twice, growing gently
# with the nights; skating ones only once there's a board and watches only once there are watches. Every kind moves
# along from the thing it asks for (Gloops popped the right way, a dizzy Crocodillo, one long grind, a big combo, a
# score in the Skate Park, a snack wrapped at the market or a parcel from Earth taken to the right friend, a place,
# a lost watch). The board and Tally are in the Market Square, the board and the Quests sheet show progress, turning
# in pays the sparkles once with a celebration, unfinished requests fade at the end of the Shift without costing
# anything (finished ones are still paid), the next Shift rolls new ones, and it all saves and loads (old saves too).
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_request_board.gd
#
# Your own save is put aside (under its own name, so another test can't swap it) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.request_board_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"

var failures := 0
var R: Node
var game: Node
var clock: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	R = root.get_node("Requests")
	game = root.get_node("Game")
	clock = root.get_node("Clock")
	var dialogue := root.get_node("Dialogue")
	var shop := root.get_node("Shop")
	clock.pulls_home = false
	game.riding = false
	game._resume = {}
	game.pending_message = ""
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	R.reset()
	# Into the Shift, in Galaxity
	clock.on_earth = false
	clock.set_time(5, 8 * 60.0, true)
	change_scene_to_file(TOWN)
	await _frames(6)
	await _physics(4)
	var town := current_scene as Node3D
	var p := town.find_child("Player", true, false) as CharacterBody3D
	check(clock.in_shift(), "it's the Shift (Galaxity day %d, %s)" % [clock.day, clock.time_string()])

	# --- The board and Tally are in the Market Square ---
	var square := town.get_node("Market Square") as Node3D
	var board := town.get_node_or_null("Request Board") as Node3D
	var tally := town.get_node_or_null("Tally") as Node3D
	check(board != null, "the request board stands in town")
	check(board != null and _flat(board.global_position - square.global_position) < 15.0,
		"...at the edge of the Market Square (%.1f m from the fountain)" % _flat(board.global_position - square.global_position))
	check(tally != null and tally.find_child("Clipboard", true, false) != null, "Tally walks the square with a clipboard")
	var t0 = tally.global_position
	await _physics(90)
	var ring := _flat(tally.global_position - square.global_position)
	check(absf(ring - 9.0) < 0.5, "...round the ring between the benches and the stalls (%.1f m out)" % ring)
	check(tally.global_position.distance_to(t0) > 0.05 or tally.get("_pause") > 0.0, "...and gets about")

	# --- Rolling ---
	await _frames(40)                                         # (the board checks twice a second)
	check(R.is_live() and R.list.size() == 3, "the Shift put three requests up (%d)" % R.list.size())
	check(R.nights == 1 and R.rolled_visit == R.visit_day(), "...for this visit, night 1")
	var tiers = R.list.map(func(r: Dictionary) -> String: return r.tier)
	check(tiers == ["easy", "medium", "hard"], "...one easy, one medium, one harder")
	var all_kinds := {}
	var never_twice := true
	var all_three := true
	for s in 300:
		R.nights = s % 12
		R.roll(s)
		var kinds := {}
		for r in R.list:
			kinds[r.kind] = true
			all_kinds[r.kind] = true
		never_twice = never_twice and kinds.size() == R.list.size()
		all_three = all_three and R.list.size() == 3
	check(all_three, "300 nights: always three")
	check(never_twice, "...never the same kind twice in a night")
	var expect := ["gloops", "crocodillo", "grind", "combo", "park_score", "deliver", "visit"]
	check(expect.all(func(k: String) -> bool: return all_kinds.has(k)), "...and every kind comes up (%s)" % ", ".join(all_kinds.keys()))
	game.items.erase("skateboard")
	var skate_free := true
	for s in 60:
		R.roll(s)
		for r in R.list:
			skate_free = skate_free and not r.kind in R.SKATE_KINDS
	check(skate_free, "without a skateboard there are no skating requests")
	game.items.append("skateboard")
	# Lost watches (scripts/watches.gd): asked for only while some are still out there to find
	var watches := root.get_node_or_null("Watches")
	var left: int = watches.call("remaining") if watches else 0
	check(R.has_watches() == (left > 0), "the board asks for lost watches only while some are left to find (%d left)" % left)
	if left > 0:
		check("watch" in R.kinds_for("medium") and not "watch" in R.kinds_for("easy"), "...as a medium or harder request")
		check(all_kinds.has("watch"), "...and they come up")
	R.nights = 1
	var first: int = _forced("grind", "hard").goal
	R.nights = 11
	var later: int = _forced("grind", "hard").goal
	R.nights = 30
	var much_later: int = _forced("grind", "hard").goal
	check(later > first and later <= first * 1.6 and much_later == later, "it grows gently with the nights (%d m, then %d, never past %d)" % [first, later, much_later])
	R.nights = 1
	var pays := [_forced("visit", "easy").sparkles, _forced("visit", "medium").sparkles, _forced("visit", "hard").sparkles]
	check(pays[0] < pays[1] and pays[1] < pays[2], "harder pays more (%s sparkles)" % str(pays))

	# --- Progress for each kind ---
	# Gloops: any way, with the popper only, or stomped only
	var any := _only(_forced("gloops", "easy", {"how": "any"}))
	R.note("gloop", 1.0, "stomp")
	R.note("gloop", 1.0, "bubble")
	check(int(any.progress) == 2, "Pop Gloops (any way) counts stomps and bubbles")
	var bubble := _only(_forced("gloops", "medium", {"how": "bubble"}))
	R.note("gloop", 1.0, "stomp")
	check(int(bubble.progress) == 0, "...'with the Star Popper' doesn't count a stomp")
	var gloop := _a_gloop(town)
	if gloop:
		gloop.shot(5, gloop.global_position, Vector3.FORWARD)
	check(int(bubble.progress) == 1, "...but a real Gloop popped by a bubble counts")
	bubble.progress = bubble.goal - 1
	R.note("gloop", 1.0, "bubble")
	check(bubble.done, "...and the last one finishes it")
	var stomp := _only(_forced("gloops", "easy", {"how": "stomp"}))
	R.note("gloop", 1.0, "bubble")
	R.note("gloop", 1.0, "stomp")
	check(int(stomp.progress) == 1, "'Stomp Gloops' only counts stomps")
	# A dizzy Crocodillo
	var croc_req := _only(_forced("crocodillo", "medium"))
	var croc = town.find_children("Crocodillo *", "", true, false)[0]
	croc.call("_defeat", true)
	check(croc_req.done, "popping a Crocodillo finishes 'Pop a dizzy Crocodillo'")
	# One long grind
	var grind := _only(_forced("grind", "easy"))
	R.note("grind", 5.0)
	R.note("grind", 4.0)
	check(int(grind.progress) == 5 and not grind.done, "grinds count the longest one, not added up (best %d m)" % int(grind.progress))
	R.note("grind", float(grind.goal) + 0.4)
	check(grind.done, "...and one long enough finishes it")
	p.skate.set("_rail_speed", 6.0)
	p.skate.set("_grind_metres", 0.0)
	var grind2 := _only(_forced("grind", "medium"))
	p.skate.set("_grind_metres", float(grind2.goal) + 1.0)
	p.skate.call("_leave_rail", Vector3.ZERO)
	check(grind2.done, "...the skater reports the metres when leaving a rail")
	# A big combo, from the skater's own banked combos
	var combo := _only(_forced("combo", "easy"))
	p.skate.tricks.banked.emit(int(combo.goal) - 100, "Kickflip")
	check(not combo.done and int(combo.progress) == int(combo.goal) - 100, "a smaller combo doesn't do it")
	p.skate.tricks.banked.emit(int(combo.goal) + 50, "Kickflip + 50-50")
	check(combo.done, "...a big enough one does")
	# A score at the Skate Park: only combos landed in the park add up
	var park_req := _only(_forced("park_score", "easy"))
	p.global_position = Vector3(0, 30, 0)
	p.skate.tricks.banked.emit(int(park_req.goal), "Kickflip")
	check(int(park_req.progress) == 0, "points away from the Skate Park don't count for its score")
	var park := town.get_node("Skate Park") as Node3D
	p.global_position = park.global_position + Vector3(0, 1.5, 0)
	await _physics(2)
	p.skate.tricks.banked.emit(int(park_req.goal) / 2, "Kickflip")
	p.skate.tricks.banked.emit(int(park_req.goal) / 2, "Heelflip")
	check(park_req.done, "...points in the park add up to the score (%d)" % int(park_req.progress))
	# Deliveries from the market: the snack is wrapped, not eaten, and goes to the right friend
	var deliver := _only(_forced("deliver", "easy"))
	game.sparkles = 50
	game.hp = 1
	shop.buy(str(deliver.item))
	check(deliver.carrying and game.hp == 1, "a snack bought for a delivery is wrapped up, not eaten")
	var who := str(deliver.who)
	dialogue.finished.emit("rook" if who != "rook" else "rex")
	check(not deliver.done, "...talking to someone else doesn't deliver it")
	dialogue.finished.emit(who)
	check(deliver.done and not deliver.carrying, "...talking to %s does" % R.friend_name(who))
	check(int(deliver.sparkles) > int(shop.items[deliver.item].price), "...and it pays more than the snack cost")
	var sweets := shop.items.values().filter(func(it: Dictionary) -> bool: return it.kind == "snack")[0] as Dictionary
	game.hp = 1
	shop.buy(str(sweets.id))
	check(game.hp > 1, "snacks nobody asked for are still eaten")
	# A place to go
	var visit := _only(_forced("visit", "medium", {"place": "observatory"}))
	p.global_position = (town.get_node("Observatory") as Node3D).global_position + Vector3(4, 2, 4)
	R._check = 0.0
	await _frames(3)
	check(visit.done, "going to the Observatory finishes 'Go to the Observatory'")
	var nest := _only(_forced("visit", "hard", {"place": "cloud_nest"}))
	var under := (town.get_node("Happy Places/HappyPlace Cloud Nest") as Node3D).global_position
	p.global_position = Vector3(under.x, under.y - 8.0, under.z)
	R._check = 0.0
	await _frames(3)
	check(not nest.done, "...standing under the Cloud Nest isn't the Cloud Nest")
	p.global_position = under
	R._check = 0.0
	await _frames(3)
	check(nest.done, "...up in it is")
	# A lost watch
	var watch := _only(_forced("watch", "hard"))
	R.note("watch")
	check(int(watch.progress) == 1 and not watch.done, "a lost watch found counts (1 of 2)")
	R.note("watch")
	check(watch.done, "...two finish it")

	# --- Earth: a parcel waits outside its building, and goes to the friend in Galaxity ---
	var earth_req := _forced("deliver", "hard")
	R.list = [earth_req]
	change_scene_to_file(EARTH)
	await _frames(8)
	await _physics(4)
	var parcel := current_scene.get_node_or_null("Parcel " + str(earth_req.item)) as Node3D
	var shop_on_earth := current_scene.get_node_or_null(str(earth_req.from)) as Node3D
	check(parcel != null, "on Earth, %s waits outside the %s" % [earth_req.item_name, earth_req.from])
	check(parcel != null and shop_on_earth != null and parcel.global_position.distance_to(shop_on_earth.global_position) < 10.0,
		"...right by it")
	if parcel:
		var ep := current_scene.find_child("Player", true, false) as CharacterBody3D
		ep.global_position = parcel.global_position + Vector3(0, 0.5, 0)
		await _physics(6)
	check(earth_req.carrying, "...walking into it picks it up")
	clock.on_earth = false
	change_scene_to_file(TOWN)
	await _frames(6)
	town = current_scene as Node3D
	p = town.find_child("Player", true, false) as CharacterBody3D
	board = town.get_node("Request Board") as Node3D
	dialogue.finished.emit(str(earth_req.who))
	check(earth_req.done, "...and %s gets it back in Galaxity" % R.friend_name(str(earth_req.who)))

	# --- Showing progress: the board and the Quests sheet ---
	R.roll(7)
	var shown = R.list[1] as Dictionary
	shown.progress = 0.0
	var text := (board.get_node("Requests") as Label3D).text
	check(R.list.all(func(r: Dictionary) -> bool: return text.contains(R.text_of(r))), "the board lists tonight's three")
	var log: String = root.get_node("Quests").log_text()
	check(log.contains("Tonight's requests") and R.list.all(func(r: Dictionary) -> bool: return log.contains(R.text_of(r))),
		"...so does the Quests sheet")
	var three: Array = R.list.duplicate()
	var gl := _forced("gloops", "hard", {"how": "any"})
	R.list = [three[0], gl, three[2]]
	R.changed.emit()
	R.note("gloop", 1.0, "stomp")
	await _frames(1)
	text = (board.get_node("Requests") as Label3D).text
	check(text.contains("1 / %d" % gl.goal), "...and moves along live (%s)" % ("1 / %d" % gl.goal))
	root.get_node("PlayerMenu").open("quests")
	await _frames(2)
	R.note("gloop", 1.0, "bubble")
	var sheet: String = root.get_node("Quests").log_view_node().text
	check(sheet.contains("2 / %d" % gl.goal), "...on the open Quests sheet too")
	root.get_node("PlayerMenu").close()
	await _frames(2)

	# --- Turning in ---
	for r in R.list:
		r.done = false
		r.paid = false
	R.list[0].done = true
	R.list[2].done = true
	var before: int = game.sparkles
	var owed: int = R.list[0].sparkles + R.list[2].sparkles
	var spot := board.get_node("Request Talk")
	p.global_position = spot.global_position + Vector3(0, 1.0, 0)
	await _physics(4)
	dialogue.talk_to(spot)
	check(dialogue.is_active(), "using the board has Tally go through the requests")
	check(game.sparkles == before + owed, "...and pays for the finished ones (+%d)" % (game.sparkles - before))
	check(R.list[0].paid and R.list[2].paid and not R.list[1].paid, "...only the finished ones")
	var said: String = dialogue._text.text
	check(not said.contains("{player}") and not said.contains("{they}"), "...with the hero's own name and pronouns filled in")
	var confetti := current_scene.find_children("*", "CPUParticles3D", true, false).size()
	check(confetti >= 4, "...and a burst of confetti (%d)" % confetti)
	while dialogue.is_active():
		dialogue._finish_typing()
		dialogue._next()
		await _frames(1)
	var again: int = R.turn_in(board)
	check(again == 0 and game.sparkles == before + owed, "turning in again pays nothing more")
	check(R.turned_in >= 2, "the board remembers how many have been turned in (%d)" % R.turned_in)

	# --- Saving and loading ---
	R.list[1].progress = 1.0
	var saved_list: Array = R.list.duplicate(true)
	var saved_visit: int = R.rolled_visit
	game.save_game()
	R.reset()
	game.load_game()
	check(R.list.size() == 3 and R.rolled_visit == saved_visit, "requests come back from the save")
	check(_same(R.list, saved_list), "...with their progress, done and paid")
	var old := JSON.parse_string(FileAccess.get_file_as_string(SAVE)) as Dictionary
	old.erase("requests")
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	game.load_game()
	check(R.list.is_empty() and R.rolled_visit == 0, "an old save without requests loads with none")
	R._check = 0.0
	await _frames(3)
	check(R.list.size() == 3, "...and gets three straight away in the Shift")

	# --- The end of the Shift: unfinished ones fade, finished ones are paid ---
	R.list[0].done = true
	R.list[0].paid = false
	before = game.sparkles
	var due: int = R.list[0].sparkles
	clock.end_shift()
	await _frames(2)
	check(R.list.is_empty() and not R.is_live(), "at the end of the Shift the requests fade away")
	check(game.sparkles == before + due, "...a finished one not turned in is still paid (+%d), and nothing's taken away" % (game.sparkles - before))
	var asleep := (board.get_node("Requests") as Label3D).text
	check(asleep.contains("asleep"), "the board says it's asleep until the next Shift")

	# --- A new night: new requests ---
	var nights_before: int = R.nights
	var last_visit: int = R.rolled_visit
	clock.on_earth = true
	clock.set_earth_time(10.0, true)                         # ten past midnight the next night: the next Shift
	clock.on_earth = false
	R._check = 0.0
	await _frames(3)
	check(R.rolled_visit == R.visit_day() and R.rolled_visit != last_visit, "the next Shift is a new visit (day %d)" % R.rolled_visit)
	check(R.list.size() == 3 and R.nights == nights_before + 1, "...with three new requests, night %d" % R.nights)
	var mid_visit: int = R.rolled_visit
	clock.advance(15 * 60.0)                                 # past Galaxity's midnight: the day number goes up...
	R._check = 0.0
	await _frames(3)
	check(R.rolled_visit == mid_visit and R.nights == nights_before + 1, "...but the same visit keeps its requests after Galaxity's midnight")

	_end()


func _forced(kind: String, tier: String, extra := {}) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var r: Dictionary = R._make(kind, tier, rng)
	r.merge(extra, true)
	return r


func _only(r: Dictionary) -> Dictionary:
	# Just this one request up tonight, to watch it move along
	R.list = [r]
	R.rolled_visit = R.visit_day()
	return r


func _a_gloop(town: Node) -> Node:
	for e in town.find_child("Enemies", true, false).get_children():
		if e.has_method("_drip") and e.name != "The Gloop King" and not e.get("defeated") and int(e.get("stomps_to_defeat")) == 1:
			return e
	return null


func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		for k in b[i]:
			if str(a[i].get(k)) != str(b[i][k]) and not (b[i][k] is float and absf(float(a[i].get(k)) - b[i][k]) < 0.01):
				return false
	return true


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _end() -> void:
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	_finish()


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit(1 if failures > 0 else 0)

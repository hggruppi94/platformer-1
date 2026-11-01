extends SceneTree

# Checks Earth's notice board (scripts/earth_jobs.gd, which is Galaxity's request board, scripts/requests.gd, with
# Earth's jobs) and Earth's shops (scripts/earth_town.gd, shop/items.json). Earth's days of the week (Clock.weekday()).
# The board stands by the gazebo with today's jobs and the festival on it; each Earth day rolls three, one easy, one
# medium and one harder, all different, the same ones after a reload and new ones the next day. Every kind moves along
# from the real thing: a parcel picked up at a shop door and taken to the right person, leaf piles walked through in
# the right yard, pumpkins picked in the patch and taken to Poppy, a lost cat found (it follows you) and taken home,
# a long grind and a big combo (on Earth only). Using the board turns finished jobs in for their sparkles once, the
# Quests sheet lists them, a new day pays anything finished and left, and it all saves and loads. The shops: a spot
# at each counter or door, each selling Earth things for sparkles, the new hats and the contest pie.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_notice_board.gd
#
# Your own save is put aside (under its own name, so another test can't swap it) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.notice_board_backup.json"
const EARTH := "res://scenes/earth/earth.tscn"

var failures := 0
var J: Node
var game: Node
var clock: Node
var dialogue: Node
var player: CharacterBody3D


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
	J = root.get_node("EarthJobs")
	game = root.get_node("Game")
	clock = root.get_node("Clock")
	dialogue = root.get_node("Dialogue")
	var shop := root.get_node("Shop")
	dialogue.reset()
	root.get_node("Quests").reset()
	game.riding = false
	game._resume = {}
	game.pending_message = ""
	game.next_spawn = "Entrance"
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	J.reset()

	# --- Earth's days of the week ---
	check(clock.weekday(1) == "Friday" and clock.weekday(2) == "Saturday" and clock.weekday(9) == "Saturday",
		"Earth's day 1 is a Friday, day 2 a Saturday, and round the week (%s, %s)" % [clock.weekday(1), clock.weekday(2)])
	clock.calendar_offset = clock.CALENDAR_START           # (the calendar as a new game has it, whatever the save said)
	clock.day = 4
	clock.minutes = 8 * 60.0
	clock.earth_minutes = 10.0
	var early: int = clock.earth_day()
	clock.day = 5
	clock.minutes = 2 * 60.0
	var later: int = clock.earth_day()
	check(early == 5 and later == 5, "after Earth's midnight it's the next Earth day, before and after Galaxity's own midnight (%d, %d)" % [early, later])
	clock.day = 4                                                # a Monday
	clock.minutes = 7 * 60.0
	clock.set_earth_time(10 * 60.0, true)
	check(not clock.in_shift() and clock.earth_day() == 4 and clock.weekday() == "Monday", "a Monday morning on Earth")

	change_scene_to_file(EARTH)
	await _frames(8)
	await _physics(4)
	var town := current_scene as Node3D
	player = town.find_child("Player", true, false) as CharacterBody3D
	var hud := town.find_child("HUD", true, false)
	await _frames(40)
	check(hud.clock_label.text.begins_with("Earth, Monday"), "the clock says the day: \"%s\"" % hud.clock_label.text.replace("\n", " / "))

	# --- The board by the gazebo ---
	var board := town.get_node_or_null("Notice Board") as Node3D
	check(board != null and board.get("earthy") == true and board.get("jobs") == J, "the notice board stands on the green")
	if board == null:
		_end()
		return
	var gazebo := town.get_node("Gazebo") as Node3D
	check(_flat(board.global_position - gazebo.global_position) < 9.0, "...by the gazebo (%.1f m)" % _flat(board.global_position - gazebo.global_position))
	check(absf(board.global_position.y - EarthLand.height(board.global_position.x, board.global_position.z)) < 0.05, "...standing on the grass")
	check(_clear_ahead(board), "...with room to walk up to it")

	# --- Rolling ---
	check(J.is_live() and J.list.size() == 3, "three jobs today (%d)" % J.list.size())
	var tiers: Array = J.list.map(func(r: Dictionary) -> String: return str(r.tier))
	var kinds: Array = J.list.map(func(r: Dictionary) -> String: return str(r.kind))
	check(tiers == ["easy", "medium", "hard"], "one easy, one medium and one harder: %s" % [tiers])
	check(kinds.size() == 3 and kinds[0] != kinds[1] and kinds[1] != kinds[2] and kinds[0] != kinds[2]
		and kinds.all(func(k: String) -> bool: return J.EARTH_KINDS.has(k)), "all different Earth kinds: %s" % [kinds])
	var text: String = (board.get("text") as Label3D).text
	check(text.begins_with("MONDAY'S JOBS") and text.contains(J.text_of(J.list[0])) and text.contains("Autumn Festival"),
		"the board shows them, and the festival: %s" % text.replace("\n", " / "))
	var first: Array = J.list.duplicate(true)
	J.nights -= 1                                              # (as it was: a reload doesn't count a night)
	J.roll(hash("earth_jobs:%d" % clock.earth_day()))
	check(_same(J.list, first), "the same day rolls the same jobs (a reload doesn't change them)")
	var seen := {}
	for d in range(10, 40):
		J.roll(hash("earth_jobs:%d" % d))
		for r in J.list:
			seen[r.kind] = true
	check(seen.size() == J.EARTH_KINDS.size(), "over a month every kind comes up: %s" % [seen.keys()])
	game.items.erase("skateboard")
	var no_skate := true
	for d in range(10, 40):
		J.roll(hash("earth_jobs:%d" % d))
		no_skate = no_skate and J.list.all(func(r: Dictionary) -> bool: return not r.kind in J.SKATE_KINDS)
	game.items.append("skateboard")
	check(no_skate, "no skating jobs without a board to ride")

	# --- Deliveries: a parcel at a shop door, to the right person ---
	var del: Dictionary = _only(_forced("deliver", "easy"))
	del.merge({"item": "rolls", "item_name": "a box of cinnamon rolls", "from": "bakery_door", "shop": "the bakery", "who": "kip"}, true)
	J._place_props()
	await _frames(3)
	var parcel := town.get_node_or_null("Job Parcel rolls") as Node3D
	var door: Vector2 = TownPaths.get_shared(TownPaths.EARTH_FILE).points["bakery_door"]
	check(parcel != null and _flat(parcel.global_position - Vector3(door.x, 0, door.y)) < 1.0, "a parcel waits at the bakery's door")
	check(J.text_of(del) == "Take a box of cinnamon rolls from the bakery to Kip", "\"%s\"" % J.text_of(del))
	if parcel:
		await _walk_into(parcel)
	check(del.carrying and not is_instance_valid(parcel), "walking into it picks it up")
	dialogue.finished.emit("gus")
	check(not del.done, "giving it to the wrong person does nothing")
	dialogue.finished.emit("kip")
	check(del.done and not del.carrying, "talking to Kip hands it over: done")

	# --- Raking: leaf piles round a house on Maple Lane ---
	var rake: Dictionary = _only(_forced("rake", "easy"))
	rake.merge({"house": "Maple House 1", "family": "Hollis", "piles": [0, 4, 9, 11], "raked": []}, true)
	J._place_props()
	await _frames(3)
	var house := town.get_node("Maple House 1") as Node3D
	var piles: Array = town.find_children("Job Leaves *", "", true, false)
	check(piles.size() == 4, "four leaf piles (%d)" % piles.size())
	check(piles.all(func(p: Node3D) -> bool: return _flat(p.global_position - house.global_position) < 10.0),
		"...round the Hollis house")
	check(piles.all(func(p: Node3D) -> bool:
		return absf(p.global_position.y - EarthLand.height(p.global_position.x, p.global_position.z)) < 0.35),
		"...on the ground, not on a fence or a roof")
	check(J.text_of(rake) == "Rake up the leaves at the Hollis house (4 piles)", "\"%s\"" % J.text_of(rake))
	for p in piles:
		await _walk_into(p)
	check(rake.done and int(rake.progress) == 4 and town.find_children("Job Leaves *", "", true, false).is_empty(),
		"walking through every pile rakes them: done (%d / 4)" % int(rake.progress))

	# --- Pumpkins for Poppy ---
	var pies: Dictionary = _only(_forced("bakery", "easy"))
	J._place_props()
	await _frames(3)
	var patch := town.find_child("Pumpkin Patch", true, false) as Node3D
	var pumpkins: Array = town.find_children("Job Pumpkin *", "", true, false)
	check(pumpkins.size() == 3 and pumpkins.all(func(p: Node3D) -> bool: return _flat(p.global_position - patch.global_position) < 9.0),
		"three glowing pumpkins in the pumpkin patch (%d)" % pumpkins.size())
	for p in pumpkins:
		await _walk_into(p)
	check(pies.carrying and not pies.done and J.progress_text(pies).contains("Poppy"), "picked them all: now to Poppy")
	dialogue.finished.emit("poppy")
	check(pies.done, "Poppy takes them: done")

	# --- A lost cat ---
	var cat: Dictionary = _only(_forced("cat", "medium"))
	cat.merge({"who": "wren", "cat": "Duchess", "coat": "grey", "hideout": "playground", "where": "by the playground slide"}, true)
	J._place_props()
	await _frames(3)
	var kitty := town.find_child("Job Cat *", true, false) as Node3D
	var slide: Vector2 = TownPaths.get_shared(TownPaths.EARTH_FILE).points["playground"]
	check(kitty != null and _flat(kitty.global_position - Vector3(slide.x, 0, slide.y)) < 3.0, "Duchess is hiding by the playground")
	if kitty:
		await _walk_into(kitty)
		check(cat.carrying and kitty.get("following") == true, "found her: she follows")
		player.global_position += Vector3(8, 0.5, 0)
		await _physics(150)
		check(is_instance_valid(kitty) and _flat(kitty.global_position - player.global_position) < 3.0,
			"...and keeps up (%.1f m behind)" % _flat(kitty.global_position - player.global_position))
	dialogue.finished.emit("dottie")
	check(not cat.done, "the wrong owner doesn't count")
	dialogue.finished.emit("wren")
	await _frames(3)
	check(cat.done and town.find_children("Job Cat *", "", true, false).is_empty(), "Mrs. Wren has her back: done, and she's gone home")

	# --- Skating ones: on Earth only ---
	var grind: Dictionary = _only(_forced("grind", "medium"))
	clock.on_earth = false
	root.get_node("Requests").note("grind", 30.0)
	check(int(grind.progress) == 0, "a grind in Galaxity doesn't count for Earth's board")
	clock.on_earth = true
	root.get_node("Requests").note("grind", 6.0)
	root.get_node("Requests").note("grind", 30.0)
	check(grind.done, "a long grind on Earth does (best %d m)" % int(grind.progress))
	var combo: Dictionary = _only(_forced("combo", "hard"))
	J._on_banked(1000, "")
	J._on_banked(int(combo.goal), "")
	check(combo.done, "a big enough combo")

	# --- Turning in at the board ---
	J.list = [_forced("rake", "easy"), _forced("cat", "medium"), _forced("bakery", "hard")]
	J.rolled_visit = clock.earth_day()
	J.list[0].done = true
	J.list[0].progress = J.list[0].goal
	J.list[2].done = true
	var want: int = int(J.list[0].sparkles) + int(J.list[2].sparkles)
	var before: int = game.sparkles
	var spot: Node = board.get_node("Request Talk")
	dialogue.talk_to(spot)
	check(dialogue.is_active(), "using the board reads it out")
	var said := ""
	while dialogue.is_active():
		dialogue._finish_typing()
		said += dialogue._text.text + " / "
		dialogue._next()
	check(game.sparkles == before + want and J.list[0].paid and J.list[2].paid and not J.list[1].paid,
		"...and turns the two finished jobs in: ✦ %d (got %d)" % [want, game.sparkles - before])
	check(said.contains("Done!") and said.contains(J.text_of(J.list[1])), "...saying so, and what's left: %s" % said.left(160))
	check(J.turn_in(board) == 0, "nothing is paid twice")
	var log: String = root.get_node("Quests").log_text()
	check(log.contains("Today's jobs") and log.contains(J.text_of(J.list[1])), "the Quests sheet lists today's jobs")

	# --- A new day ---
	J.list[1].done = true
	before = game.sparkles
	clock.day += 1
	J._check = 0.0
	await _frames(3)
	check(J.rolled_visit == clock.earth_day() and J.list.size() == 3 and J.list.all(func(r: Dictionary) -> bool: return not r.done),
		"the next day puts up three new jobs")
	check(game.sparkles > before, "...and pays the one finished yesterday that wasn't turned in")

	# --- Saving ---
	J.list[0].progress = 1.0
	if J.list[0].has("raked"):
		J.list[0].raked = [3]
	var saved: Array = J.list.duplicate(true)
	game.save_game()
	J.reset()
	game.load_game()
	check(_same(J.list, saved) and J.rolled_visit == clock.earth_day(), "today's jobs save and load")
	check(J.list.all(func(r: Dictionary) -> bool: return not r.has("raked") or r.raked.all(func(v) -> bool: return v is int)),
		"(with the raked piles' numbers as whole numbers)")
	J.load_data({})
	check(J.list.is_empty() and J.nights == 0, "a save from before the board has no jobs (new ones come at once)")

	# --- The shops ---
	for s in [["Bakery", "Bakery"], ["Toy Shop", "Toy Shop"], ["Diner", "Hollow Diner"], ["Corner Market", "Corner Market"]]:
		var b := town.get_node(s[1]) as Node3D
		var shop_spot := b.get_node_or_null("Shop " + s[0]) as Area3D
		check(shop_spot != null and shop.for_stall(s[0]).size() >= 2, "%s: a shop spot, selling %d things" % [s[0], shop.for_stall(s[0]).size()])
		if shop_spot:
			check(_room_at(shop_spot.global_position), "...with room to stand at it")
			var inside := b.get_node_or_null("Inside") as Node3D
			if inside:
				check(absf(shop_spot.global_position.y - inside.global_position.y) < 0.3, "...inside, on the shop's floor")
	game.sparkles = 40
	check(shop.buy("witch_hat") and game.outfit.get("head", "") == "witch_hat", "buying the Witch Hat puts it on")
	check(root.get_node("Shop").can_buy("pumpkin_hat") == "" and Cosmetics.hat("pumpkin_hat") != null, "the Pumpkin Hat has a look too")
	game.items.erase("contest_pie")
	check(shop.buy("contest_pie") and game.has_item("contest_pie"), "a contest pie from the bakery, for the festival")
	check(shop.can_buy("contest_pie") != "", "...one at a time")
	game.items.erase("contest_pie")
	var all_earth: Array = shop.items.values().filter(func(i: Dictionary) -> bool:
		return i.stall in ["Bakery", "Toy Shop", "Diner", "Corner Market", "Festival Treats", "Cider Cart"])
	check(all_earth.size() >= 15 and all_earth.all(func(i: Dictionary) -> bool: return int(i.price) <= 20),
		"%d Earth things for sale, none over 20 sparkles" % all_earth.size())
	_end()


func _forced(kind: String, tier: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	return J._make(kind, tier, rng)


func _only(r: Dictionary) -> Dictionary:
	J.list = [r]
	J.rolled_visit = clock.earth_day()
	return r


func _walk_into(n: Node3D) -> void:
	player.velocity = Vector3.ZERO
	player.global_position = n.global_position + Vector3(0, 0.3, 0)
	await _physics(6)
	player.global_position += Vector3(0, 0, 40)               # (well away, so the next one is walked into afresh)
	await _physics(3)


func _clear_ahead(board: Node3D) -> bool:
	return _room_at(board.global_transform * Vector3(0, 0, 1.6))


func _room_at(p: Vector3) -> bool:
	# Nothing solid where someone would stand
	var q := PhysicsShapeQueryParameters3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.3
	q.shape = s
	q.transform = Transform3D(Basis(), p + Vector3(0, 0.9, 0))
	q.collide_with_areas = false
	q.exclude = [player.get_rid()]
	return (current_scene as Node3D).get_world_3d().direct_space_state.intersect_shape(q, 4).is_empty()


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
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit(1 if failures > 0 else 0)

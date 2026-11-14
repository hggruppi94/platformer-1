extends SceneTree

# Checks the schematics and the new rides (scripts/schematics.gd, scripts/schematic_pickup.gd, Rides.HERO_RIDES,
# scenes/player/ride_kit.gd; Hayden: "the weapons can stay locked until they are unlocked and purchased"):
# Dash's stall lists every gadget from the start, the Star Popper too, but each one says "Find its blueprint" until
# it's yours (Hayden, 11 Nov: nobody starts with a blaster; 13 Nov: "Instead of randomly finding blueprints, make them
# rewards for completing races/quests"); Zippy's Tune-Up has the five new rides the same way; a ride's schematic is
# only out from its own night; every one lands on open ground (or, the sky one, in open air); walking into one finds
# it. Gadget blueprints are never on the ground: Dash gives the Star Popper's for catching his bot, Melody and Otto
# theirs when their worlds are mended (not on a practice trip), and the rest are races' first prizes; an old save that
# already earned one gets it when it loads; a world's isn't hinted at before its portal opens; an old save's gadgets
# stay its own; each new ride
# builds, rides, saves and swaps on the Skate page; rocket rides boost harder; and the Goals page points to the next.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_schematics.gd
#
# Your own save is put aside (under its own name) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.schematics_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0
var S: Node
var game: Node
var shop: Node
var arsenal: Node
var dialogue: Node
var requests: Node
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
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	S = root.get_node("Schematics")
	game = root.get_node("Game")
	shop = root.get_node("Shop")
	arsenal = root.get_node("Arsenal")
	dialogue = root.get_node("Dialogue")
	requests = root.get_node("Requests")
	root.get_node("Clock").pulls_home = false
	root.get_node("Settings").tips = false
	game.message_posted.connect(func(t: String) -> void: messages.append(t))
	dialogue.reset()
	root.get_node("Quests").reset()
	arsenal.reset()
	game.items.clear()
	game.give_item("skateboard")
	game.hero_ride = "board"
	game.riding = false
	game._resume = {}
	requests.nights = 1
	# This visit's board counts as already put up: otherwise, with a save whose clock is in the Shift, going into town
	# rolls the board and counts a new night (scripts/requests.gd roll()), and night 1 turns into night 2.
	requests.rolled_visit = requests.visit_day()

	# --- Everything's on the shelf, but locked ---
	var gadgets: Array = shop.items.values().filter(func(it: Dictionary) -> bool: return str(it.kind) == "gadget")
	check(gadgets.size() == 7, "Dash's stall lists all seven gadgets, the Star Popper too (%d)" % gadgets.size())
	check(gadgets.all(func(it: Dictionary) -> bool: return shop.can_buy(str(it.id)) == "Find its blueprint"),
		"...and every one says \"Find its blueprint\" at the start")
	check(arsenal.owned.is_empty(), "...and she has none")
	game.sparkles = 999
	check(not shop.buy("fizz_flinger") and not arsenal.owns("fizz") and game.sparkles == 999,
		"...so even with lots of sparkles you can't buy one yet")
	var rides: Array = shop.items.values().filter(func(it: Dictionary) -> bool: return str(it.kind) == "ride")
	check(rides.size() == 6 and rides.all(func(it: Dictionary) -> bool: return str(it.stall) == "Tune-Up"),
		"Zippy's Tune-Up lists the six new rides (%s)" % str(rides.map(func(it: Dictionary) -> String: return str(it.name))))
	# (The Hover Bike has no schematic: it's the Bike made to float, at a level. tools/test_ride_upgrades.gd)
	check(rides.all(func(it: Dictionary) -> bool: return shop.can_buy(str(it.id)) == ("Needs the Bike first" if str(it.ride) == "hover_bike" else "Find its schematic")),
		"...each locked behind its schematic")
	check(rides.all(func(it: Dictionary) -> bool: return int(it.price) > 0 and int(it.price) <= 20), "...each 20 sparkles or less")
	var portals := root.get_node("Portals")
	portals.reset()
	var disco_note := str(shop.kinds.gadget.note.call(shop.items["disco_ball"]))
	check(disco_note.contains("Not yet") and not disco_note.contains("Rhythm"),
		"a gadget that's a world's thank-you doesn't name the world before its portal's open (%s)" % disco_note)
	check(str(shop.kinds.gadget.note.call(shop.items["fizz_flinger"])).contains("winning the Lake Loop"),
		"a race's first prize says which race to win (%s)" % shop.kinds.gadget.note.call(shop.items["fizz_flinger"]))
	var whats := {}
	for e in S.LIST:
		whats[str(e.kind) + ":" + str(e.what)] = e
	check(str(whats.get("gadget:popper", {}).get("reward", {}).get("flag", "")) == "bb_thanked",
		"the Star Popper's blueprint is Dash's thank-you for catching his bot")
	var races := root.get_node("Races")
	for g in arsenal.ORDER:
		var e: Dictionary = whats.get("gadget:" + g, {})
		check(not e.is_empty() and e.has("reward") and S.where(e) == "", "the %s's blueprint is a reward, never on the ground (%s)" % [g, str(e.get("reward", {}))])
		var r: Dictionary = e.get("reward", {})
		if r.has("race"):
			check(races.TRACKS.has(str(r.race)) and races.TRACKS[str(r.race)].has("circuit"), "...first prize in a circuit race (%s)" % r.race)
		elif r.has("world"):
			check(portals.is_built(str(r.world)), "...a thank-you in a portal world that's built (%s)" % r.world)
	check(str(whats.get("gadget:disco", {}).get("reward", {}).get("world", "")) == "rhythm_springs", "the Disco Ball's is Melody's, from her music world")
	check(S.for_race("lake_loop").get("what", "") == "fizz", "winning the Lake Loop gives the Fizz Flinger's")
	for r in ["overboard", "bike", "rocket_board", "rocket_bike", "saucer"]:
		check(whats.has("ride:" + r), "the %s has a schematic (night %d)" % [r, int(whats.get("ride:" + r, {}).get("night", 0))])
	for n in range(2, 8):
		var nq: Dictionary = root.get_node("Quests").quest("night_%d" % n)
		var flags: Array = []
		for st in nq.steps:
			for c in st.get("checklist", []):
				flags.append(str(c[0]))
		check(not flags.any(func(f: String) -> bool: return f.begins_with("schematic_") and str(S.entry(f.trim_prefix("schematic_")).get("kind", "")) == "gadget"),
			"night %d's list doesn't send you for a gadget's blueprint (they're in the portal worlds now)" % n)

	# --- Only from their own night ---
	await _go(TOWN)
	var names: Array = _pickups().map(func(n: Node) -> String: return str(n.name))
	check(names.is_empty(), "on the first night no blueprint's lying about (%s)" % str(names))
	requests.nights = 7
	await _go(TOWN)
	var town_ones: Array = S.LIST.filter(func(e: Dictionary) -> bool: return S.where(e) == "town")
	check(_pickups().size() == town_ones.size(), "by night 7 all %d of the town's are out (%d)" % [town_ones.size(), _pickups().size()])

	# --- Each lands somewhere you can get to ---
	await _frames(4)
	var space := (current_scene as Node3D).get_world_3d().direct_space_state
	for p in _pickups():
		var e: Dictionary = S.entry(str(p.id))
		var at: Vector3 = p.global_position
		if e.has("sky"):
			check(_clear(space, at + Vector3(0, 2.5, 0), 6.0), "%s: in open air the mothership can fly through" % e.id)
			continue
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3(0, 0.3, 0), at + Vector3(0, -0.4, 0)))
		check(not hit.is_empty(), "%s: on the ground at (%.0f, %.1f, %.0f)" % [e.id, at.x, at.y, at.z])
		check(at.y > -1.0 and pow(at.x / 40.0, 2) + pow(at.z / 17.0, 2) > 1.0 and pow((at.x + 5) / 34.0, 2) + pow((at.z + 32) / 7.0, 2) > 1.0, "%s: not down in the lake (%.1f)" % [e.id, at.y])
		check(_clear(space, at + Vector3(0, 0.9, 0), 0.45), "%s: not inside a wall, a tree or a building" % e.id)

	# --- Earning one: Dash's thank-you ---
	var player := current_scene.find_child("Player", true, false) as CharacterBody3D
	messages.clear()
	check(not S.is_found("popper"), "(no Star Popper blueprint before Dash's thanks)")
	dialogue.set_flag("bb_thanked")                     # (an old save already past it: given as it loads)
	await _physics(150)
	check(S.is_found("popper") and dialogue.flags.has("schematic_popper"), "Dash's thanks for catching his bot gives the Star Popper's blueprint")
	check(messages.any(func(m: String) -> bool: return m.contains("Star Popper") and m.contains("Dash") and m.contains("blueprint")),
		"...and says Dash can build it now")
	check(shop.can_buy("star_popper") == "", "now the Star Popper can be bought")
	game.sparkles = 40
	check(shop.buy("star_popper") and arsenal.owns("popper") and arsenal.armed() and game.sparkles == 37,
		"...and bought, for 3 sparkles")
	portals.quake("rhythm_springs", true)
	disco_note = str(shop.kinds.gadget.note.call(shop.items["disco_ball"]))
	check(disco_note.contains("Rhythm Springs"), "once its world's portal is open, a locked gadget says where to look (%s)" % disco_note)
	portals.reset()

	# --- An old save's gadgets stay its own ---
	arsenal.give("disco", false)
	check(shop.can_buy("disco_ball") == "You have this one" and S.gadget_unlocked("disco"),
		"a gadget an old save already has stays its own, schematic or not")

	# --- The Goals page points to the next one ---
	var aim: Array = root.get_node("Nights").goals()[1][1]
	check(aim.any(func(l: String) -> bool: return l.begins_with("Gadgets: the Fizz Flinger's blueprint") and l.contains("Lake Loop")),
		"the Goals page says which blueprint to earn next, and how (%s)" % str(aim))

	# --- Rides ---
	game.level = 9                                       # rides wait for a level too (scripts/ride_upgrades.gd)
	for r in S.RIDE_PRICES:
		var ride: Dictionary = _ride_for(str(r))
		check(str(ride.kit) != "board" or r == "rocket_board", "%s: has its own kit (%s)" % [r, ride.kit])
		check(float(ride.push_speed) >= 9.0 and float(ride.max_speed) > float(ride.push_speed), "%s: pushes at %.1f m/s, up to %.1f" % [r, ride.push_speed, ride.max_speed])
		check((ride.tricks as Dictionary).has("flips") and (ride.tricks as Dictionary).has("special"), "%s: has its own tricks (%s)" % [r, ride.tricks.special[0]])
		var holder := Node3D.new()
		root.add_child(holder)
		var parts: Dictionary = RideKit.build(str(ride.kit), holder, player.model)
		check(holder.get_child_count() > 0, "%s: its ride is built (%d parts)" % [r, holder.get_child_count()])
		check((parts.get("flames") != null) == bool(ride.get("flames", false)), "%s: %s" % [r, "rockets with flames" if ride.get("flames", false) else "no rockets"])
		holder.queue_free()
	check(str(_ride_for("bike").tricks.flips[""][0]) == "Tailwhip", "the Bike does BMX tricks, like Dash's")

	S.pick_up("overboard")
	check(shop.can_buy("ride_overboard") == "", "finding the Overboard's schematic lets Zippy build it")
	game.sparkles = 40
	check(shop.buy("ride_overboard") and game.has_item("ride:overboard") and game.hero_ride == "overboard",
		"buying it, and it's what you ride now")
	game.riding = true
	game.equipment_changed.emit()
	await _frames(3)
	var skate: Node = player.get("skate")
	check(str(skate.ride.kit) == "overboard" and player.board.get_child_count() > 0, "the hero's on the Overboard (%s)" % skate.ride.kit)
	check(await _rides_along(player), "...and it rolls along")

	# Rocket rides push harder off boosts
	for r in ["rocket_board", "rocket_bike", "saucer", "bike", "hover_bike"]:
		S.pick_up(r)
		game.sparkles = 40
		shop.buy("ride_" + r)
		await _frames(2)
		check(game.hero_ride == r and str(skate.ride.kit) == str(_ride_for(r).kit), "the %s can be bought and ridden" % r)
		check(await _rides_along(player), "...and it rolls along")
	S.use_ride("rocket_board")
	await _frames(2)
	skate.boost(5.0, 1.0)
	check(is_equal_approx(float(skate.get("_boost_speed")), 7.0), "the Rocket Board's rockets make a boost 40%% stronger (%.1f)" % float(skate.get("_boost_speed")))
	var flames := player.board.find_child("Flames", true, false) as Node3D
	await _frames(20)
	var flame := flames.get_child(0) as Node3D if flames else null
	check(flame != null and flame.scale.z > 1.3, "...and its flames burn big while it boosts (%.2f)" % (flame.scale.z if flame else 0.0))

	# --- The Skate page swaps rides ---
	var menu := root.get_node("PlayerMenu")
	menu.open("skate")
	await _frames(3)
	var row: Node = menu.root.find_child("Rides", true, false)
	var buttons: Array = row.get_children().filter(func(c: Node) -> bool: return c is Button) if row else []
	check(buttons.size() == 7, "the Skate page has a button for each ride she has (%d)" % buttons.size())
	var bb := row.find_child("Ride board", true, false) as Button if row else null
	if bb:
		bb.pressed.emit()
	await _frames(3)
	check(game.hero_ride == "board" and str(skate.ride.kit) == "board", "...and picking the Skateboard puts her back on it")
	menu.close()
	await _frames(2)

	# --- Saving ---
	S.use_ride("saucer")
	game.save_game()
	game.hero_ride = "board"
	game.load_game()
	check(game.hero_ride == "saucer", "the ride you're on is saved")
	var f := FileAccess.open(SAVE, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	data.items = (data.items as Array).filter(func(i) -> bool: return str(i) != "ride:saucer")
	f = FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	game.load_game()
	check(game.hero_ride == "board", "...and a save riding something it doesn't have rides the board")
	data.erase("hero_ride")
	f = FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	game.load_game()
	check(game.hero_ride == "board" and S.is_found("popper"), "a save from before the rides rides the board, and keeps what it found")

	# --- Rewards an old save had already earned are given as it plays on ---
	requests.nights = 7
	game.riding = false
	races.wins["meadow_wiggle"] = 1                     # (won before first prizes were a thing)
	messages.clear()
	await _physics(45)
	check(S.is_found("buzz"), "a race already won gives its first prize's blueprint (the Buzz Bots')")
	check(not S.is_found("fizz") and not S.is_found("rainbow") and not S.is_found("plush"), "...and only that race's")
	# A world mended: its friend's thank-you (handed over in the world itself; here, the save already had it mended)
	dialogue.flags.erase("schematic_jelly")
	await _go(str(portals.world("tide_reef").scene))
	portals.cleared_worlds.append("tide_reef")
	await _physics(45)
	check(not S.is_found("jelly"), "in the Tide Reef itself the blueprint waits for Otto's thank-you")
	check(current_scene.get_node_or_null("Schematic jelly") == null, "...and there's none lying about in a world")
	await _go(TOWN)
	await _physics(45)
	check(S.is_found("jelly") and messages.any(func(m: String) -> bool: return m.contains("Otto") and m.contains("Jelly Mines")),
		"back in town with the Tide Reef mended, Otto's thank-you is yours (the Jelly Mines' blueprint)")
	game.sparkles = 40
	check(shop.can_buy("jelly_mines") == "" and shop.buy("jelly_mines") and arsenal.owns("jelly"), "...and then Dash builds it")
	# Melody's thank-you in Rhythm Springs gives it straight away, but not on a practice trip
	var rs: GDScript = load("res://scripts/rhythm_springs.gd")
	check(str(rs.new().teach_lines()).contains("Disco Ball"), "Melody's thank-you lines hand over the Disco Ball's blueprint")
	var tr: GDScript = load("res://scripts/tide_reef.gd")
	check(str(tr.new().teach_lines()).contains("Jelly Mines"), "...and Otto's the Jelly Mines'")
	portals.reset()

	_put_save_back()
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)


func _ride_for(r: String) -> Dictionary:
	var was: String = game.hero_ride
	game.hero_ride = r
	var out: Dictionary = Rides.ride("hero")
	game.hero_ride = was
	return out


func _rides_along(player: CharacterBody3D) -> bool:
	# Push forward for a second on open ground, and see she gets going without falling off
	player.global_position = Vector3(-4, 1.5, 24)
	player.velocity = Vector3.ZERO
	await _physics(4)
	Input.action_press("move_forward")
	var top := 0.0
	for i in 70:
		await physics_frame
		top = maxf(top, Vector2(player.velocity.x, player.velocity.z).length())
	Input.action_release("move_forward")
	var skate: Node = player.get("skate")
	print("    (top speed %.1f m/s)" % top)
	return top > 4.0 and int(skate.state) != int(skate.State.BAIL)


func _clear(space: PhysicsDirectSpaceState3D, at: Vector3, r: float) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var ball := SphereShape3D.new()
	ball.radius = r
	q.shape = ball
	q.transform = Transform3D(Basis(), at)
	for got in space.intersect_shape(q, 8):
		var c: Object = got.collider
		if c is StaticBody3D or c is CSGShape3D:
			return false
	return true


func _pickups() -> Array:
	return current_scene.get_children().filter(func(n: Node) -> bool: return String(n.name).begins_with("Schematic "))


func _go(scene: String) -> void:
	change_scene_to_file(scene)
	for i in 30:
		await process_frame
		if current_scene and current_scene.scene_file_path == scene:
			break
	await _frames(6)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _put_save_back() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")

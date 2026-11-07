extends SceneTree

# Checks the ride upgrades you get as you level up (scripts/ride_upgrades.gd, Rides.HERO_RIDES, scenes/player/skate.gd;
# Hayden, 7 Nov: "new vehicle mechanics as you level up to hover and rocket boards/bikes, with the rocket ones capable
# of flight"): boards and bikes go plain, hover, rocket; Zippy waits for each one's level (and the Hover Bike for the
# Bike); a level-up says what's opened; an old save's rides stay its own; riding gives XP (races, gaps, skate-run
# medals); hover rides float across the lake while the plain board wades, and goo can't slow them; rocket rides fly
# (Jump again in the air), burn fuel, stop climbing at the ceiling, float down softly and land clean, refuel on the
# ground and from a boost; no flying in a race; the HUD has a fuel bar; and the Goals page says what level is next.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_ride_upgrades.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.ride_upgrades_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.ride_upgrades_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0
var game: Node
var shop: Node
var S: Node
var U: Node
var races: Node
var messages: Array = []


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
	shop = root.get_node("Shop")
	S = root.get_node("Schematics")
	U = root.get_node("RideUpgrades")
	races = root.get_node("Races")
	var settings := root.get_node("Settings")
	settings.tips = false
	settings.skate_assist = 1
	settings.control_style = "classic"
	root.get_node("Clock").pulls_home = false
	root.get_node("Clock").set_time(1, 12 * 60.0, true)
	game.message_posted.connect(func(t: String) -> void: messages.append(t))
	root.get_node("Dialogue").reset()
	root.get_node("Quests").reset()
	races.reset()
	game._resume = {}
	game.pending_message = ""
	game.riding = false
	game.items.clear()
	game.give_item("skateboard")
	game.hero_ride = "board"
	game.level = 1
	game.xp = 0
	game.sparkles = 999
	root.get_node("Requests").nights = 7
	root.get_node("Requests").rolled_visit = root.get_node("Requests").visit_day()

	# --- The three steps for boards and bikes ---
	for line in Rides.LINES:
		var steps: Array = Rides.LINES[line]
		check(steps.size() == 3, "%s: plain, hover and rocket (%s)" % [line, str(steps)])
		check(not Rides.HERO_RIDES[steps[0]].get("hover", false) and not Rides.HERO_RIDES[steps[0]].get("flight", false),
			"...the %s is the plain one" % Rides.HERO_RIDES[steps[0]].name)
		check(Rides.HERO_RIDES[steps[1]].get("hover", false), "...the %s hovers" % Rides.HERO_RIDES[steps[1]].name)
		check(Rides.HERO_RIDES[steps[2]].get("flight", false), "...the %s flies" % Rides.HERO_RIDES[steps[2]].name)
		check(U.level_for(steps[0]) < U.level_for(steps[1]) and U.level_for(steps[1]) < U.level_for(steps[2]),
			"...each needs a higher level (Lv %d, %d, %d)" % [U.level_for(steps[0]), U.level_for(steps[1]), U.level_for(steps[2])])
	check(shop.items.has("ride_hover_bike") and str(shop.items.ride_hover_bike.stall) == "Tune-Up" and int(shop.items.ride_hover_bike.price) <= 20,
		"the Hover Bike is on Zippy's Tune-Up")
	check(S.for_thing("ride", "hover_bike").is_empty(), "...and needs no schematic (it's the Bike, made to float)")

	# --- Zippy waits for the level ---
	for e in S.LIST:
		if str(e.kind) == "ride":
			S.pick_up(str(e.id))
	check(shop.can_buy("ride_bike") == "", "the plain Bike only needs its schematic (%s)" % shop.can_buy("ride_bike"))
	check(shop.can_buy("ride_overboard") == "Reach Lv 2", "at Lv 1 the Overboard says \"Reach Lv 2\" (%s)" % shop.can_buy("ride_overboard"))
	check(not shop.buy("ride_overboard") and not game.has_item("ride:overboard"), "...and can't be built yet, however many sparkles")
	check(str(shop.kinds.ride.note.call(shop.items.ride_overboard)).contains("XP to go"),
		"...its note says how much XP to go (%s)" % shop.kinds.ride.note.call(shop.items.ride_overboard))
	check(shop.can_buy("ride_hover_bike") == "Needs the Bike first", "the Hover Bike needs the Bike first (%s)" % shop.can_buy("ride_hover_bike"))
	check(shop.can_buy("ride_rocket_board") == "Reach Lv 5", "the Rocket Board waits for Lv 5 (%s)" % shop.can_buy("ride_rocket_board"))
	check(U.xp_to_level(2) == 10 and U.xp_to_level(3) == 30, "XP to go adds up (Lv 2: %d, Lv 3: %d)" % [U.xp_to_level(2), U.xp_to_level(3)])
	var goals: Array = root.get_node("Nights").goals()[1][1]
	check(goals.any(func(l: String) -> bool: return l.contains("Zippy can build you the Bike")), "the Goals page: build the Bike now (%s)" % str(goals))
	check(shop.buy("ride_bike"), "building the Bike")
	game.give_item("ride:saucer")                         # (so the next goal isn't the Saucer, ready to build)
	goals = root.get_node("Nights").goals()[1][1]
	check(goals.any(func(l: String) -> bool: return l.contains("reach Lv 2") and l.contains("Overboard")),
		"...then the Goals page says which level opens the next ride (%s)" % str(goals))
	check(shop.can_buy("ride_hover_bike") == "Reach Lv 3", "with the Bike, the Hover Bike waits for Lv 3 (%s)" % shop.can_buy("ride_hover_bike"))

	# --- Levelling up opens them ---
	messages.clear()
	game.add_xp(10)
	check(game.level == 2 and shop.can_buy("ride_overboard") == "", "at Lv 2 the Overboard can be built")
	check(messages.any(func(m: String) -> bool: return m.contains("Overboard") and m.contains("Zippy")), "...and a level-up says so (%s)" % str(messages))
	messages.clear()
	game.add_xp(100)
	check(game.level == 5, "more XP, more levels (Lv %d)" % game.level)
	check(messages.any(func(m: String) -> bool: return m.contains("Hover Bike")), "...Lv 3 says the Hover Bike's ready")
	check(shop.buy("ride_hover_bike") and game.hero_ride == "hover_bike", "the Hover Bike can be built, and it's your ride now")
	var hb := _ride_for("hover_bike")
	check(str(hb.tricks.flips[""][0]) == "Tailwhip" and float(hb.deck) > 0.2, "...it does BMX tricks, floating up off the ground")

	# --- An old save's rides stay its own ---
	game.level = 1
	game.xp = 0
	game.give_item("ride:rocket_bike")
	check(shop.can_buy("ride_rocket_bike") == "You have this one" and U.level_ok("rocket_bike"),
		"a ride an old save already has stays its own at any level")
	S.use_ride("rocket_bike")
	check(game.hero_ride == "rocket_bike", "...and can be ridden")

	# --- Riding gives XP ---
	var xp0 := _total_xp()
	races.finished.emit("lake_loop", 1)
	check(_total_xp() - xp0 == U.RACE_XP[0], "winning a race gives %d XP (%d)" % [U.RACE_XP[0], _total_xp() - xp0])
	xp0 = _total_xp()
	races.finished.emit("lake_loop", 6)
	check(_total_xp() - xp0 == U.RACE_XP[3], "...and any finish gives some (%d)" % (_total_xp() - xp0))
	xp0 = _total_xp()
	root.get_node("Gaps").found.emit("test")
	check(_total_xp() - xp0 == U.GAP_XP, "a new gap gives %d XP" % U.GAP_XP)
	var runs: Node = root.get_node("SkateRuns")
	var run_id: String = runs.RUNS.keys()[0]
	await _frames(2)                                      # RideUpgrades notes the medals before the run
	runs.medals[run_id] = 2
	xp0 = _total_xp()
	runs.finished.emit(run_id, 99999)
	var gained := _total_xp() - xp0
	check(gained == U.MEDAL_XP[0] + U.MEDAL_XP[1], "a skate run's two new medals give %d XP (%d)" % [U.MEDAL_XP[0] + U.MEDAL_XP[1], gained])
	xp0 = _total_xp()
	runs.finished.emit(run_id, 99999)
	check(_total_xp() == xp0, "...the same medals again give nothing")
	runs.medals.erase(run_id)

	# --- On the water ---
	game.level = 9
	for r in ["overboard", "rocket_board"]:
		game.give_item("ride:" + r)
	change_scene_to_file(TOWN)
	await _frames(10)
	await _physics(4)
	var player := current_scene.find_child("Player", true, false) as CharacterBody3D
	var lake := current_scene.find_child("Lake", true, false)
	var water: Node = null
	for w in get_nodes_in_group("water"):
		if (w as Node).is_ancestor_of(lake) or w == lake or lake.is_ancestor_of(w):
			water = w
	if water == null and not get_nodes_in_group("water").is_empty():
		water = get_nodes_in_group("water")[0]
	check(water != null and water.has_method("covers"), "the lake's water can be found by rides")
	var wy: float = float(water.water_y) if water else -0.6
	game.riding = true
	S.use_ride("overboard")
	await _frames(3)
	var skate: Node = player.get("skate")
	check(skate.hovers(), "the Overboard is a hover ride")
	var on := await _ride_on_lake(player, skate)
	check(on.feet > wy - 0.02 and on.feet < wy + 0.15, "the Overboard floats on the lake (feet %.2f, water %.2f)" % [on.feet, wy])
	check(on.moved > 6.0 and int(skate.state) != int(skate.State.BAIL), "...and rides along it (%.1f m)" % on.moved)
	check(on.water, "...and knows it's on water (ripples)")
	skate.gooed(3.0)
	check(not skate.slowed(), "goo can't slow a hover ride")
	S.use_ride("hover_bike")
	await _frames(3)
	on = await _ride_on_lake(player, skate)
	check(on.feet > wy - 0.02 and on.feet < wy + 0.15 and on.moved > 6.0, "the Hover Bike floats across too (feet %.2f, %.1f m)" % [on.feet, on.moved])
	S.use_ride("board")
	await _frames(3)
	on = await _ride_on_lake(player, skate)
	check(on.feet < wy - 0.1, "the plain Skateboard still wades in (feet %.2f)" % on.feet)
	skate.gooed(3.0)
	check(skate.slowed(), "...and goo still slows it")
	skate.set("_slow_time", 0.0)

	# --- Flying ---
	S.use_ride("rocket_board")
	await _frames(3)
	check(skate.can_fly(), "the Rocket Board can fly")
	var hud: Node = skate.hud
	var fuel_bar := hud.find_child("Fuel", true, false) as Control
	await _frames(2)
	check(fuel_bar != null and fuel_bar.visible, "its fuel bar shows on the HUD")
	player.global_position = Vector3(-4, 1.5, 30)
	player.velocity = Vector3.ZERO
	player.spring_arm.rotation.y = 0.0
	await _physics(8)
	var ground_y := player.global_position.y
	check(is_equal_approx(float(skate.fuel), skate.FLY_FUEL), "a full tank to start (%.1f)" % float(skate.fuel))
	Input.action_press("move_forward")
	await _physics(30)
	# Ollie (hold and let go), then Jump again and hold: the rockets
	Input.action_press("jump")
	await _physics(6)
	Input.action_release("jump")
	await _physics(4)
	check(int(skate.state) == int(skate.State.AIR), "an ollie into the air")
	Input.action_press("jump")
	var top := 0.0
	for i in 120:
		await physics_frame
		top = maxf(top, player.global_position.y - ground_y)
	check(skate.flying, "holding Jump in the air fires the rockets")
	check(top > 8.0, "...and up she goes (%.1f m up after 2 s)" % top)
	check(float(skate.fuel) < skate.FLY_FUEL - 1.5, "...burning fuel (%.1f left)" % float(skate.fuel))
	var flat := Vector2(player.velocity.x, player.velocity.z).length()
	check(flat > 6.0, "...flying forward, not just up (%.1f m/s)" % flat)
	Input.action_release("jump")
	var fastest := 0.0
	var bailed := false
	skate.bailed.connect(func() -> void: bailed = true)
	for i in 600:
		await physics_frame
		fastest = minf(fastest, player.velocity.y)
		if int(skate.state) == int(skate.State.ROLL):
			break
	check(fastest > -skate.FLY_FLOAT - 0.6, "letting go, she floats down gently (fastest fall %.1f m/s)" % fastest)
	check(int(skate.state) == int(skate.State.ROLL) and not bailed, "...and lands clean, riding away")
	Input.action_release("move_forward")
	var f0: float = skate.fuel
	await _physics(60)
	check(float(skate.fuel) > f0 + 0.8, "the tank fills up again on the ground (%.1f to %.1f)" % [f0, float(skate.fuel)])
	skate.fuel = 0.5
	skate.boost(3.0, 0.5)
	check(is_equal_approx(float(skate.fuel), skate.FLY_FUEL), "a boost fills it right up")
	await _physics(40)

	# The ceiling: with a tank that never ends she still stops climbing
	player.global_position = Vector3(-4, 1.5, 30)
	player.velocity = Vector3.ZERO
	await _physics(8)
	Input.action_press("jump")
	await _physics(6)
	Input.action_release("jump")
	await _physics(4)
	Input.action_press("jump")
	top = 0.0
	for i in 480:
		skate.fuel = skate.FLY_FUEL
		await physics_frame
		top = maxf(top, player.global_position.y - ground_y)
	Input.action_release("jump")
	check(top < skate.FLY_CEILING + 3.0 and top > skate.FLY_CEILING - 4.0, "she stops climbing at the ceiling (%.1f m, ceiling %.0f)" % [top, skate.FLY_CEILING])
	for i in 900:
		await physics_frame
		if int(skate.state) == int(skate.State.ROLL):
			break
	check(int(skate.state) == int(skate.State.ROLL) and not bailed, "...and a long way down is still a soft, clean landing")

	# No flying in a race on the ground
	races.state = races.State.RACING
	check(not skate.can_fly(), "no flying in a race (the rockets just boost there)")
	races.state = races.State.IDLE

	# The plain board can't fly, and pressing Jump in the air does nothing new
	S.use_ride("board")
	await _frames(3)
	check(not skate.can_fly() and not (hud.find_child("Fuel", true, false) as Control).visible, "the plain Skateboard doesn't fly, and has no fuel bar")

	_finish()


func _ride_on_lake(player: CharacterBody3D, skate: Node) -> Dictionary:
	# Drop her onto the middle of the main lake and push north along it; where are her feet after a while?
	player.global_position = Vector3(10, 1.0, 10)
	player.velocity = Vector3.ZERO
	skate.set("_yaw", PI)
	player.spring_arm.rotation.y = 0.0                  # the camera behind her, looking north over the lake
	await _physics(6)
	var start := player.global_position
	var water := false
	Input.action_press("move_forward")
	for i in 150:
		await physics_frame
		water = water or bool(skate.on_water)
	Input.action_release("move_forward")
	var feet := player.global_position.y - 0.8
	var moved := Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()
	print("    (feet at %.2f, moved %.1f m, at %s)" % [feet, moved, str(player.global_position)])
	player.velocity = Vector3.ZERO
	return {"feet": feet, "moved": moved, "water": water}


func _total_xp() -> int:
	# Every bit of XP so far, whatever level it's made
	var t: int = game.xp
	for l in range(1, game.level):
		t += 10 * l
	return t


func _ride_for(r: String) -> Dictionary:
	var was: String = game.hero_ride
	game.hero_ride = r
	var out: Dictionary = Rides.ride("hero")
	game.hero_ride = was
	return out


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	for a in ["move_forward", "jump"]:
		Input.action_release(a)
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.remove_absolute(SETTINGS)
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)

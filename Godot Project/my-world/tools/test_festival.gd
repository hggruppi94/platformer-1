extends SceneTree

# Checks the Autumn Festival on Earth's green (scripts/festival.gd, festival_green.gd, apple_bobbing.gd) and the old
# oak's story hints (scripts/earth_town.gd). The festival is on Saturday evenings, 5 to 10 PM, and only then: its
# stalls, pie table, apple barrel, lantern stall, banner and hayride go up round the gazebo without blocking anyone's
# way, and the people who run them are at them (their routines' "festival" blocks). The pie contest takes a contest
# pie and gives a ribbon and sparkles once a festival; apple bobbing pays for apples once a festival and holds the
# player still while they bob; the hayride carries the player round the street for a lap and lets them off; at nine
# the lanterns go up, and the player's own if they got one. At ten it all comes down. Then the oak: its hum rises
# towards midnight, a tremor or two a night gets people talking (Mr. Palmer says it's pipes), and the envelope on his
# porch. The festival's prizes save and load.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_festival.gd
#
# Your own save is put aside (under its own name, so another test can't swap it) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.festival_backup.json"
const EARTH := "res://scenes/earth/earth.tscn"

var failures := 0
var F: Node
var T: Node
var game: Node
var clock: Node
var dialogue: Node
var player: CharacterBody3D
var town: Node3D


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
	F = root.get_node("Festival")
	T = root.get_node("EarthTown")
	game = root.get_node("Game")
	clock = root.get_node("Clock")
	dialogue = root.get_node("Dialogue")
	dialogue.reset()
	root.get_node("Quests").reset()
	F.reset()
	game.riding = false
	game._resume = {}
	game.pending_message = ""
	game.next_spawn = "Entrance"
	game.items.erase("contest_pie")
	clock.calendar_offset = clock.CALENDAR_START           # (the calendar as a new game has it, whatever the save said)
	clock.day = 2                                              # Saturday
	clock.minutes = 7 * 60.0
	clock.set_earth_time(16 * 60.0, true)
	change_scene_to_file(EARTH)
	await _frames(8)
	await _physics(4)
	town = current_scene as Node3D
	player = town.find_child("Player", true, false) as CharacterBody3D
	player.global_position = Vector3(0, 1, 16)

	# --- When it's on ---
	check(clock.weekday() == "Saturday" and F.is_festival_day() and not F.is_on(), "Saturday afternoon: festival day, not on yet")
	check(root.get_node("Quests").log_text().contains("Tonight:"), "the Quests sheet says it's tonight")
	await _wait(0.7)
	check(town.get_node_or_null("Autumn Festival") == null, "nothing up on the green yet")
	clock.set_earth_time(17 * 60.0 + 30.0, true)
	await _wait(0.7)
	var green := town.get_node_or_null("Autumn Festival") as Node3D
	check(F.is_on() and green != null, "at 5:30 PM it's on, and up on the green")
	if green == null:
		_end()
		return
	for n in ["Treats/Shop Festival Treats", "Cider/Shop Cider Cart", "Apples/Apple Barrel", "Lanterns/Lantern Stall", "Pies",
			"Hay", "Hay Wagon/Hayride", "Tractor"]:
		check(green.get_node_or_null(n) != null, "the festival has %s" % n)
	# Nobody's way blocked: every festival point and its links clear, the stalls clear of the trees
	var paths := TownPaths.get_shared(TownPaths.EARTH_FILE)
	var space := town.get_world_3d().direct_space_state
	var bad := []
	for name in paths.points:
		if str(name).begins_with("fest_") or name == "gazebo":
			var p: Vector2 = paths.points[name]
			if not _room_at(Vector3(p.x, EarthLand.height(p.x, p.y), p.y)):
				bad.append(name)
	check(bad.is_empty(), "every festival point has room to stand %s" % [bad])
	var blocked := []
	for l in paths.links:
		if str(l[0]).begins_with("fest_") or str(l[1]).begins_with("fest_"):
			var a: Vector2 = paths.points[l[0]]
			var b: Vector2 = paths.points[l[1]]
			var q := PhysicsRayQueryParameters3D.create(Vector3(a.x, 0.5, a.y), Vector3(b.x, 0.5, b.y))
			q.exclude = TownPaths.skip_rids(town)
			if space.intersect_ray(q):
				blocked.append(l)
	check(blocked.is_empty(), "every festival path is clear with the festival up %s" % [blocked])
	check(_flat(green.get_node("Treats").global_position) > 8.0 and _flat(green.get_node("Treats").global_position) < 11.0,
		"the stalls stand between the gazebo and the trees")

	# --- The people who run it ---
	await _physics(10)
	for who in [["poppy", "fest_treats_stall", "festival_stall"], ["gus", "fest_cider_stall", "festival_cider"],
			["dottie", "fest_pies_stall", "festival_judge"], ["hank", "fest_apples_stall", "festival_apples"],
			["marigold", "fest_lanterns_stall", "festival_lanterns"], ["barnaby", "gazebo", "festival_music"]]:
		var r: Node = dialogue.routine_of(who[0])
		var at: Vector2 = paths.points[who[1]]
		var body := r.get_parent() as Node3D if r else null
		check(r and r.current_block().get("place", "") == who[1] and r.activity() == who[2] and body
			and _flat(body.global_position - Vector3(at.x, 0, at.y)) < 3.0,
			"%s is at %s (%s)" % [who[0], who[1], r.activity() if r else "?"])
	dialogue.talks["dottie"] = 3
	check(dialogue._pick("dottie").get("do", "") == "Festival.judge_pie", "Dottie's judging the pies")

	# --- The pie contest ---
	var lines: Array = F.judge_pie()
	check(" ".join(lines).contains("contest bakes at the bakery"), "no pie: she says where to get one")
	game.sparkles = 30
	root.get_node("Shop").buy("contest_pie")
	var before: int = game.sparkles
	lines = F.judge_pie()
	check(F.ribbons == [1, 0, 0] and game.sparkles == before + F.PIE_PRIZES[0] and not game.has_item("contest_pie"),
		"the first pie wins: blue ribbon, ✦ %d (%s)" % [F.PIE_PRIZES[0], lines[2] if lines.size() > 2 else lines])
	game.items.append("contest_pie")
	lines = F.judge_pie()
	check(lines[0].contains("already") and game.has_item("contest_pie") and F.ribbons == [1, 0, 0], "one pie a festival")
	game.items.erase("contest_pie")

	# --- Bobbing for apples ---
	F.start_bobbing()
	await _frames(2)
	var bob: Node = F.bobbing()
	check(bob != null and player.input_locked, "bobbing for apples holds the player still")
	if bob:
		bob.marker = bob.zone
		var a1: bool = bob.bite()
		bob._wait = 0.0
		bob._next_go()
		bob.marker = fposmod(bob.zone + 0.5, 1.0)
		var a2: bool = bob.bite()
		bob._wait = 0.0
		bob._next_go()
		bob.marker = bob.zone + 0.02
		var a3: bool = bob.bite()
		check(a1 and not a2 and a3 and bob.apples == 2, "biting over the ripple gets an apple, missing it splashes")
		before = game.sparkles
		bob._finish()
		check(game.sparkles == before + 2 and F.apples_day == clock.earth_day(), "two apples: ✦ 2")
		bob.close()
		await _frames(2)
		check(not player.input_locked and F.bobbing() == null, "...and the player can move again")
		before = game.sparkles
		check(F.apples_done(3).contains("3 apples") and game.sparkles == before, "again just for fun: no more prize tonight")

	# --- The hayride ---
	var gr: Node = green
	var loop_ok := true
	for k in 60:
		var p: Vector3 = gr.point_at(gr.loop_length() * k / 60.0)
		var side := maxf(absf(p.x), absf(p.z))
		loop_ok = loop_ok and side > 17.0 and side < 22.0
	check(loop_ok, "the hayride keeps to the street round the green (%.0f m a lap)" % gr.loop_length())
	gr.hop_on()
	await _physics(5)
	check(gr.riding and player.get("carried") == true and player.global_position.distance_to(gr.wagon.global_position) < 2.0,
		"hopping on: carried along on the wagon")
	gr._wait = 0.0
	var start := player.global_position
	await _physics(60)
	check(player.global_position.distance_to(start) > 2.0, "...round the green (%.1f m)" % player.global_position.distance_to(start))
	gr._d = gr.loop_length() - 0.2
	await _physics(10)
	await _wait(0.4)
	check(not gr.riding and player.get("carried") == false and F.hayrides == 1 and not player.input_locked,
		"a whole lap, then off at the stop (%d rides)" % F.hayrides)

	# --- Lanterns at nine ---
	F.lantern_lines()
	check(F.lantern_day == clock.earth_day(), "a lantern from Miss Marigold's stall")
	player.global_position = Vector3(0, 1, 16)
	before = game.sparkles
	clock.set_earth_time(21 * 60.0, true)
	await _wait(0.5)
	check(gr.lantern_count() == gr.LANTERN_COUNT, "at nine the lanterns go up (%d)" % gr.lantern_count())
	check(F.lanterns_let_go == 1 and game.sparkles == before + F.LANTERN_PRIZE, "...and the player's own")
	var l0: Node3D = gr._lanterns[0]
	var y0 := l0.position.y
	await _wait(0.5)
	check(l0.position.y > y0, "...floating up")

	# --- Ten o'clock ---
	clock.set_earth_time(22 * 60.0 + 1.0, true)
	await _wait(0.7)
	await _physics(4)
	check(not F.is_on() and town.get_node_or_null("Autumn Festival") == null, "at ten it all comes down")
	var poppy: Node = dialogue.routine_of("poppy")
	check(poppy.current_block().get("place", "") != "fest_treats_stall", "...and Poppy's back to her own evening")
	clock.day = 3
	clock.set_earth_time(18 * 60.0, true)
	await _wait(0.7)
	check(not F.is_on() and town.get_node_or_null("Autumn Festival") == null, "Sunday evening: no festival")

	# --- Saving ---
	var saved: Dictionary = F.save_data()
	game.save_game()
	F.reset()
	game.load_game()
	check(F.save_data() == saved, "the festival's ribbons and prizes save and load")
	F.load_data({})
	check(F.ribbons == [0, 0, 0] and F.pie_day == 0, "a save from before the festival starts with none")

	# --- The old oak ---
	clock.day = 4
	check(T.hum_level() == 0.0, "the oak's quiet at 6 PM")
	clock.set_earth_time(23 * 60.0, true)
	check(T.hum_level() > 0.5, "...humming by 11 PM (%.2f)" % T.hum_level())
	var oak: Node = town.get_node_or_null("Portal Home/Oak Hum")
	check(oak != null and oak.get_child_count() >= 2, "the hum comes from the old oak, with a glow")
	var times: Array = T.tremor_times()
	check(times.size() >= 1 and times.size() <= 2 and times.all(func(t: float) -> bool: return t >= 22 * 60.0 and t < 24 * 60.0)
		and times == T.tremor_times(), "one or two tremors tonight, the same after a reload (%s)" % [times.map(func(t: float) -> String: return clock.format_time(t))])
	dialogue.flags.erase("earth_tremor")
	clock.set_earth_time(times[0] - 1.0, true)
	await _wait(0.4)
	var felt: int = T.tremors_felt
	clock.set_earth_time(times[0] + 0.5, true)
	await _wait(0.4)
	check(T.tremors_felt == felt + 1 and dialogue.flags.has("earth_tremor"), "a tremor at %s" % clock.format_time(times[0]))
	dialogue.talks["palmer_earth"] = 5
	check(" ".join(dialogue._pick("palmer_earth").get("lines", [])).contains("pipes"), "Mr. Palmer: it's the pipes")
	var letter: Node = town.get_node_or_null("Palmer House/Palmer's Letter")
	check(letter != null, "an envelope on Mr. Palmer's porch")
	var said := " ".join(T.letter_lines())
	check(said.contains("GALAXITY") and dialogue.flags.has("read_palmer_letter"), "...addressed to the Mayor, in Galaxity")
	dialogue.flags["palmer_tremor_talk"] = true
	check(" ".join(dialogue._pick("palmer_earth").get("lines", [])).contains("pen pal"), "...and he has an answer for that too")
	clock.set_earth_time(10.0, true)
	check(T.hum_level() == 1.0, "in the Shift it hums its loudest")
	_end()


func _room_at(p: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.3
	q.shape = s
	q.transform = Transform3D(Basis(), p + Vector3(0, 0.9, 0))
	q.collide_with_areas = false
	q.exclude = TownPaths.skip_rids(town)
	return town.get_world_3d().direct_space_state.intersect_shape(q, 4).is_empty()


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _wait(s: float) -> void:
	await create_timer(s).timeout


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
